import 'dart:convert';
import 'dart:math';

import 'package:flashnote/core/utils/desktop_canvas_shortcuts.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/entities/inspiration_link.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_link_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KnowledgeGraphPage extends ConsumerStatefulWidget {
  const KnowledgeGraphPage({super.key});

  @override
  ConsumerState<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends ConsumerState<KnowledgeGraphPage> {
  final TransformationController _transformationController =
      TransformationController();
  int _graphVersion = 0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(inspirationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.knowledgeGraph),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<Inspiration>>(
        future: repo.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final inspirations = snapshot.data ?? [];
          if (inspirations.length < 2) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noInspirationsForGraph,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<InspirationLink>>(
            future: _loadAllLinks(inspirations),
            builder: (context, linkSnapshot) {
              if (linkSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final links = linkSnapshot.data ?? [];
              final graphKey = inspirations.map((i) => i.id).toList()..sort();
              return _GraphCanvas(
                key: ValueKey('${graphKey.join("_")}_$_graphVersion'),
                inspirations: inspirations,
                links: links,
                transformationController: _transformationController,
                onLinksChanged: () {
                  if (mounted) setState(() => _graphVersion++);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<InspirationLink>> _loadAllLinks(
    List<Inspiration> inspirations,
  ) async {
    final repo = ref.read(inspirationLinkRepositoryProvider);
    final allLinks = <InspirationLink>[];
    final seenIds = <int>{};

    for (final ins in inspirations) {
      final links = await repo.getLinksForInspiration(ins.id);
      for (final link in links) {
        if (seenIds.add(link.id)) {
          allLinks.add(link);
        }
      }
    }
    return allLinks;
  }
}

class _GraphCanvas extends ConsumerStatefulWidget {
  const _GraphCanvas({
    super.key,
    required this.inspirations,
    required this.links,
    required this.transformationController,
    required this.onLinksChanged,
  });

  final List<Inspiration> inspirations;
  final List<InspirationLink> links;
  final TransformationController transformationController;
  final VoidCallback onLinksChanged;

  @override
  ConsumerState<_GraphCanvas> createState() => _GraphCanvasState();
}

enum _GraphConnectPattern { chain, center }

class _GraphCanvasState extends ConsumerState<_GraphCanvas> {
  static const _layoutCacheVersion = 2;
  static const _nodeWidth = 184.0;
  static const _nodeHeight = 112.0;
  static const _canvasPadding = 520.0;

  late final double _canvasSize;
  late List<Offset> _positions;
  late Map<int, int> _idToIndex;
  final List<int> _selectionOrder = [];
  final FocusNode _focusNode = FocusNode(debugLabel: 'knowledge-graph-canvas');
  LinkType _selectedLinkType = LinkType.similar;
  _GraphConnectPattern _connectPattern = _GraphConnectPattern.chain;
  bool _loaded = false;
  bool _centered = false;
  bool _connectMode = false;
  bool _middlePanning = false;
  Offset? _lastPanGlobal;
  int? _hoveredInspirationId;

  String get _cacheKey {
    final ids = widget.inspirations.map((i) => i.id).toList()..sort();
    return 'graph_positions_v${_layoutCacheVersion}_${ids.join("_")}';
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _canvasSize = max(3200.0, sqrt(widget.inspirations.length) * 720);
    _idToIndex = {};
    for (int i = 0; i < widget.inspirations.length; i++) {
      _idToIndex[widget.inspirations[i].id] = i;
    }
    _positions = List.generate(
      widget.inspirations.length,
      (_) => Offset(_canvasSize / 2, _canvasSize / 2),
    );
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    var shouldLayout = cachedJson == null;

    if (cachedJson != null) {
      try {
        final payload = jsonDecode(cachedJson) as Map<String, dynamic>;
        final version = payload['version'] as int?;
        final canvasSize = (payload['canvasSize'] as num?)?.toDouble();
        final positions = payload['positions'];
        if (version != _layoutCacheVersion ||
            canvasSize == null ||
            (canvasSize - _canvasSize).abs() > 1 ||
            positions is! Map<String, dynamic>) {
          shouldLayout = true;
        } else {
          final map = positions;
          for (int i = 0; i < widget.inspirations.length; i++) {
            final id = widget.inspirations[i].id.toString();
            final raw = map[id];
            if (raw is List && raw.length >= 2) {
              _positions[i] = Offset(
                (raw[0] as num).toDouble(),
                (raw[1] as num).toDouble(),
              );
            } else {
              _positions[i] = _initialPosition(i);
              shouldLayout = true;
            }
          }
        }
      } catch (_) {
        shouldLayout = true;
      }
    }

    if (shouldLayout) {
      _positions = List.generate(widget.inspirations.length, _initialPosition);
      _runForceDirectedLayout();
      await _savePositions();
    }

    if (mounted) setState(() => _loaded = true);
  }

  Offset _initialPosition(int index) {
    final center = Offset(_canvasSize / 2, _canvasSize / 2);
    final ring = 180.0 + (index ~/ 10) * 220.0;
    final angle = index * pi * (3 - sqrt(5));
    final jitter = Random(widget.inspirations[index].id).nextDouble() * 80;
    return center + Offset(cos(angle), sin(angle)) * (ring + jitter);
  }

  Future<void> _savePositions() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (int i = 0; i < widget.inspirations.length; i++) {
      map[widget.inspirations[i].id.toString()] = [
        _positions[i].dx,
        _positions[i].dy,
      ];
    }
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'version': _layoutCacheVersion,
        'canvasSize': _canvasSize,
        'nodeWidth': _nodeWidth,
        'nodeHeight': _nodeHeight,
        'positions': map,
      }),
    );
  }

  void _runForceDirectedLayout() {
    const iterations = 180;
    const idealDistance = 250.0;
    const repulsionForce = 54000.0;
    const attractionForce = 0.018;
    const centerGravity = 0.002;
    const damping = 0.82;
    final center = Offset(_canvasSize / 2, _canvasSize / 2);
    final velocities = List.generate(_positions.length, (_) => Offset.zero);

    for (int iter = 0; iter < iterations; iter++) {
      final forces = List.generate(_positions.length, (_) => Offset.zero);

      for (int i = 0; i < _positions.length; i++) {
        for (int j = i + 1; j < _positions.length; j++) {
          final delta = _positions[i] - _positions[j];
          final dist = delta.distance.clamp(8.0, 900.0);
          final direction = delta / dist;
          final force = repulsionForce / (dist * dist);
          forces[i] += direction * force;
          forces[j] -= direction * force;
        }
      }

      for (final link in widget.links) {
        final si = _idToIndex[link.sourceId];
        final ti = _idToIndex[link.targetId];
        if (si == null || ti == null) continue;
        final delta = _positions[ti] - _positions[si];
        final dist = delta.distance.clamp(1.0, double.infinity);
        final direction = delta / dist;
        final weight = 0.7 + link.confidence;
        final force = (dist - idealDistance) * attractionForce * weight;
        forces[si] += direction * force;
        forces[ti] -= direction * force;
      }

      for (int i = 0; i < _positions.length; i++) {
        final toCenter = center - _positions[i];
        forces[i] += toCenter * centerGravity;
        velocities[i] = (velocities[i] + forces[i]) * damping;
        _positions[i] = _clampPosition(_positions[i] + velocities[i]);
      }
    }
  }

  Offset _clampPosition(Offset position) {
    return Offset(
      position.dx.clamp(_canvasPadding, _canvasSize - _canvasPadding),
      position.dy.clamp(_canvasPadding, _canvasSize - _canvasPadding),
    );
  }

  Color _linkColor(LinkType type, ColorScheme scheme) {
    switch (type) {
      case LinkType.similar:
        return scheme.primary;
      case LinkType.causal:
        return const Color(0xFFF97316);
      case LinkType.complementary:
        return const Color(0xFF10B981);
      case LinkType.opposite:
        return const Color(0xFFEF4444);
      case LinkType.parentChild:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _linkTypeIcon(LinkType type) {
    switch (type) {
      case LinkType.similar:
        return Icons.compare_arrows_rounded;
      case LinkType.causal:
        return Icons.arrow_right_alt_rounded;
      case LinkType.complementary:
        return Icons.add_circle_outline_rounded;
      case LinkType.opposite:
        return Icons.swap_horiz_rounded;
      case LinkType.parentChild:
        return Icons.account_tree_rounded;
    }
  }

  String _linkTypeLabel(LinkType type, AppLocalizations l10n) {
    switch (type) {
      case LinkType.similar:
        return l10n.linkTypeSimilar;
      case LinkType.causal:
        return l10n.linkTypeCausal;
      case LinkType.complementary:
        return l10n.linkTypeComplementary;
      case LinkType.opposite:
        return l10n.linkTypeOpposite;
      case LinkType.parentChild:
        return l10n.linkTypeParentChild;
    }
  }

  void _centerView() {
    if (_centered || _positions.isEmpty) return;
    _centered = true;

    var minX = _positions.first.dx;
    var minY = _positions.first.dy;
    var maxX = _positions.first.dx;
    var maxY = _positions.first.dy;
    for (final pos in _positions) {
      minX = min(minX, pos.dx);
      minY = min(minY, pos.dy);
      maxX = max(maxX, pos.dx);
      maxY = max(maxY, pos.dy);
    }
    final graphWidth = (maxX - minX) + _nodeWidth + 320;
    final graphHeight = (maxY - minY) + _nodeHeight + 320;
    final graphCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size == null) return;
      final scale = min(
        size.width / graphWidth,
        size.height / graphHeight,
      ).clamp(0.22, 1.05);
      final tx = size.width / 2 - graphCenter.dx * scale;
      final ty = size.height / 2 - graphCenter.dy * scale;
      widget.transformationController.value = Matrix4(
        scale,
        0,
        0,
        0,
        0,
        scale,
        0,
        0,
        0,
        0,
        1,
        0,
        tx,
        ty,
        0,
        1,
      );
    });
  }

  void _zoomBy(double factor) {
    final size = context.size;
    if (size == null) return;
    final currentScale =
        widget.transformationController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.12, 4.0);
    final center = Offset(size.width / 2, size.height / 2);
    final sceneCenter = widget.transformationController.toScene(center);
    widget.transformationController.value =
        Matrix4.identity()
          ..translateByDouble(center.dx, center.dy, 0, 1)
          ..scaleByDouble(targetScale, targetScale, 1, 1)
          ..translateByDouble(-sceneCenter.dx, -sceneCenter.dy, 0, 1);
  }

  Future<void> _resetLayout() async {
    setState(() {
      _selectionOrder.clear();
      _connectMode = false;
      _positions = List.generate(widget.inspirations.length, _initialPosition);
      _runForceDirectedLayout();
      _centered = false;
    });
    widget.transformationController.value = Matrix4.identity();
    await _savePositions();
    _centerView();
  }

  void _startMiddlePan(PointerDownEvent event) {
    _focusNode.requestFocus();
    _middlePanning = true;
    _lastPanGlobal = event.position;
  }

  void _updateMiddlePan(PointerMoveEvent event) {
    if (!_middlePanning || _lastPanGlobal == null) return;
    final delta = event.position - _lastPanGlobal!;
    _lastPanGlobal = event.position;
    widget.transformationController.value =
        widget.transformationController.value.clone()
          ..translateByDouble(delta.dx, delta.dy, 0, 1);
  }

  void _endMiddlePan([PointerEvent? _]) {
    _middlePanning = false;
    _lastPanGlobal = null;
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final copy = _GraphCopy.of(context);
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(value: 'fit', child: Text(copy.fitView)),
        PopupMenuItem<String>(
          value: 'connect',
          child: Text(_connectMode ? copy.exitConnect : copy.connect),
        ),
        if (_hoveredInspirationId != null)
          PopupMenuItem<String>(value: 'open', child: Text(copy.openIdea)),
      ],
    );
    if (!mounted || value == null) return;
    switch (value) {
      case 'fit':
        _centered = false;
        _centerView();
      case 'connect':
        _toggleConnectMode();
      case 'open':
        if (_hoveredInspirationId != null) {
          context.push('/inspiration/$_hoveredInspirationId');
        }
    }
  }

  void _toggleConnectMode() {
    setState(() {
      _connectMode = !_connectMode;
      if (!_connectMode) _selectionOrder.clear();
    });
  }

  void _toggleSelection(int inspirationId) {
    setState(() {
      if (_selectionOrder.contains(inspirationId)) {
        _selectionOrder.remove(inspirationId);
      } else {
        _selectionOrder.add(inspirationId);
      }
    });
  }

  void _clearSelection() {
    setState(_selectionOrder.clear);
  }

  void _onNodeDrag(int index, DragUpdateDetails details) {
    final scale = widget.transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _positions[index] = _clampPosition(
        _positions[index] + details.delta / scale.clamp(0.1, 8.0),
      );
    });
  }

  Future<void> _createSelectedLinks() async {
    if (_selectionOrder.length < 2) return;

    final copy = _GraphCopy.of(context);
    final linkRepo = ref.read(inspirationLinkRepositoryProvider);
    final processedLinks = <InspirationLink>[];
    var createdCount = 0;
    var removedCount = 0;
    var skippedCount = 0;
    var cycleCount = 0;

    final pairs = _selectedPairs();

    for (final pair in pairs) {
      final sourceId = pair.$1;
      final targetId = pair.$2;
      if (sourceId == targetId) continue;

      final exists = await linkRepo.getLinkBetween(
        sourceId,
        targetId,
        linkType: _selectedLinkType,
        directed: _selectedLinkType == LinkType.parentChild,
      );
      if (exists != null) {
        if (_selectedLinkType == LinkType.parentChild) {
          await linkRepo.delete(exists.id);
          processedLinks.add(exists);
          removedCount++;
        } else {
          skippedCount++;
        }
        continue;
      }

      if (_selectedLinkType == LinkType.parentChild) {
        if (await linkRepo.wouldCreateParentChildCycle(sourceId, targetId)) {
          cycleCount++;
          continue;
        }
      } else if (await linkRepo.exists(sourceId, targetId)) {
        skippedCount++;
        continue;
      }

      final link = InspirationLink(
        id: 0,
        sourceId: sourceId,
        targetId: targetId,
        linkType: _selectedLinkType,
        relationLabel:
            _selectedLinkType == LinkType.parentChild ? 'belongsTo' : null,
        confidence: 1.0,
        createdAt: DateTime.now(),
      );
      final id = await linkRepo.create(link);
      processedLinks.add(link.copyWith(id: id));
      createdCount++;
    }

    if (!mounted) return;
    setState(() {
      _connectMode = false;
      _selectionOrder.clear();
    });
    widget.onLinksChanged();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copy.linkResult(
              createdCount,
              skippedCount,
              removedCount,
              cycleCount,
              _selectedLinkType == LinkType.parentChild,
            ),
          ),
          action:
              processedLinks.isEmpty
                  ? null
                  : SnackBarAction(
                    label: copy.undo,
                    onPressed: () async {
                      for (final link in processedLinks.reversed) {
                        final existing = await linkRepo.getById(link.id);
                        if (existing == null) {
                          await linkRepo.restore(link);
                        } else {
                          await linkRepo.delete(link.id);
                        }
                      }
                      widget.onLinksChanged();
                    },
                  ),
        ),
      );
  }

  List<(int, int)> _selectedPairs() {
    if (_selectedLinkType == LinkType.parentChild &&
        _connectPattern == _GraphConnectPattern.center &&
        _selectionOrder.length >= 2) {
      final parentId = _selectionOrder.first;
      return [
        for (final childId in _selectionOrder.skip(1)) (parentId, childId),
      ];
    }
    return [
      for (var i = 0; i < _selectionOrder.length - 1; i++)
        (_selectionOrder[i], _selectionOrder[i + 1]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    _centerView();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _GraphCopy.of(context);
    final colorScheme = theme.colorScheme;
    final selectedIds = _selectionOrder.toSet();

    return CallbackShortcuts(
      bindings: {
        DesktopCanvasShortcuts.fitView: () {
          _centered = false;
          _centerView();
        },
        DesktopCanvasShortcuts.zoomIn: () => _zoomBy(1.12),
        DesktopCanvasShortcuts.zoomOut: () => _zoomBy(1 / 1.12),
        DesktopCanvasShortcuts.reset: () {
          setState(() => _selectionOrder.clear());
        },
        DesktopCanvasShortcuts.escape: () {
          if (_connectMode || _selectionOrder.isNotEmpty) {
            setState(() {
              _connectMode = false;
              _selectionOrder.clear();
            });
          }
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: MouseRegion(
          cursor:
              _middlePanning
                  ? SystemMouseCursors.move
                  : SystemMouseCursors.grab,
          child: Listener(
            onPointerDown: (event) {
              if (event.kind == PointerDeviceKind.mouse &&
                  event.buttons == kMiddleMouseButton) {
                _startMiddlePan(event);
              }
              if (event.kind == PointerDeviceKind.mouse &&
                  event.buttons == kSecondaryMouseButton) {
                _showContextMenu(event.position);
              }
            },
            onPointerMove: _updateMiddlePan,
            onPointerUp: _endMiddlePan,
            onPointerCancel: _endMiddlePan,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: widget.transformationController,
                  boundaryMargin: const EdgeInsets.all(10000),
                  minScale: 0.12,
                  maxScale: 4.0,
                  trackpadScrollCausesScale: true,
                  scaleFactor: 180,
                  constrained: false,
                  child: SizedBox(
                    width: _canvasSize,
                    height: _canvasSize,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GraphBackgroundPainter(
                              backgroundColor: colorScheme.surface,
                              gridColor: colorScheme.outlineVariant,
                              centerColor: colorScheme.primary,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              positions: _positions,
                              links: widget.links,
                              idToIndex: _idToIndex,
                              linkColor:
                                  (type) => _linkColor(type, colorScheme),
                            ),
                          ),
                        ),
                        if (_selectionOrder.length > 1)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SelectionPathPainter(
                                positions: _positions,
                                selectedIds: _selectionOrder,
                                idToIndex: _idToIndex,
                                color: _linkColor(
                                  _selectedLinkType,
                                  colorScheme,
                                ),
                              ),
                            ),
                          ),
                        for (int i = 0; i < widget.inspirations.length; i++)
                          Positioned(
                            left: _positions[i].dx,
                            top: _positions[i].dy,
                            child: FractionalTranslation(
                              translation: const Offset(-0.5, -0.5),
                              child: _NodeWidget(
                                inspiration: widget.inspirations[i],
                                width: _nodeWidth,
                                maxHeight: _nodeHeight,
                                selected: selectedIds.contains(
                                  widget.inspirations[i].id,
                                ),
                                hovered:
                                    _hoveredInspirationId ==
                                    widget.inspirations[i].id,
                                connectMode: _connectMode,
                                accentColor: _nodeAccent(
                                  widget.inspirations[i].id,
                                ),
                                selectionIndex: _selectionOrder.indexOf(
                                  widget.inspirations[i].id,
                                ),
                                onTap: () {
                                  if (_connectMode) {
                                    _toggleSelection(widget.inspirations[i].id);
                                  } else {
                                    context.push(
                                      '/inspiration/${widget.inspirations[i].id}',
                                    );
                                  }
                                },
                                onDoubleTap:
                                    () => context.push(
                                      '/inspiration/${widget.inspirations[i].id}',
                                    ),
                                onHoverChanged: (hovered) {
                                  if (!mounted) return;
                                  setState(() {
                                    _hoveredInspirationId =
                                        hovered
                                            ? widget.inspirations[i].id
                                            : null;
                                  });
                                },
                                onPanUpdate:
                                    (details) => _onNodeDrag(i, details),
                                onPanEnd: (_) => _savePositions(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: _GraphHud(
                    linkCount: widget.links.length,
                    nodeCount: widget.inspirations.length,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _SelectionToolbar(
                    connectMode: _connectMode,
                    selectedCount: _selectionOrder.length,
                    selectedLinkType: _selectedLinkType,
                    connectPattern: _connectPattern,
                    linkTypeLabel: (type) => _linkTypeLabel(type, l10n),
                    linkTypeIcon: _linkTypeIcon,
                    onTypeChanged:
                        (type) => setState(() {
                          _selectedLinkType = type;
                          if (type != LinkType.parentChild) {
                            _connectPattern = _GraphConnectPattern.chain;
                          }
                        }),
                    onPatternChanged:
                        (pattern) => setState(() => _connectPattern = pattern),
                    onFitView: () {
                      _centered = false;
                      _centerView();
                    },
                    onResetLayout: _resetLayout,
                    onToggleConnectMode: _toggleConnectMode,
                    onClear: _clearSelection,
                    onCreate: _createSelectedLinks,
                    copy: copy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _nodeAccent(int id) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF0891B2),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
    ];
    return colors[id.abs() % colors.length];
  }
}

class _GraphHud extends StatelessWidget {
  const _GraphHud({required this.nodeCount, required this.linkCount});

  final int nodeCount;
  final int linkCount;

  @override
  Widget build(BuildContext context) {
    final copy = _GraphCopy.of(context);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final metrics = [
            AppMetricChip(
              icon: Icons.account_tree_outlined,
              label: copy.nodes(nodeCount),
            ),
            AppMetricChip(
              icon: Icons.hub_outlined,
              label: copy.links(linkCount),
            ),
          ];

          return AppPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child:
                compact
                    ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(spacing: 8, runSpacing: 8, children: metrics),
                      ],
                    )
                    : Row(
                      children: [
                        metrics[0],
                        const SizedBox(width: 8),
                        metrics[1],
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.connectMode,
    required this.selectedCount,
    required this.selectedLinkType,
    required this.connectPattern,
    required this.linkTypeLabel,
    required this.linkTypeIcon,
    required this.onTypeChanged,
    required this.onPatternChanged,
    required this.onFitView,
    required this.onResetLayout,
    required this.onToggleConnectMode,
    required this.onClear,
    required this.onCreate,
    required this.copy,
  });

  final bool connectMode;
  final int selectedCount;
  final LinkType selectedLinkType;
  final _GraphConnectPattern connectPattern;
  final String Function(LinkType) linkTypeLabel;
  final IconData Function(LinkType) linkTypeIcon;
  final ValueChanged<LinkType> onTypeChanged;
  final ValueChanged<_GraphConnectPattern> onPatternChanged;
  final VoidCallback onFitView;
  final VoidCallback onResetLayout;
  final VoidCallback onToggleConnectMode;
  final VoidCallback onClear;
  final VoidCallback onCreate;
  final _GraphCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: AppPanel(
        padding: const EdgeInsets.all(12),
        radius: 28,
        shadowAlpha: 0.12,
        borderColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: copy.fitView,
                  onPressed: onFitView,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: copy.resetLayout,
                  onPressed: onResetLayout,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onToggleConnectMode,
                    icon: Icon(
                      connectMode
                          ? Icons.close_rounded
                          : Icons.add_link_rounded,
                    ),
                    label: Text(connectMode ? copy.exitConnect : copy.connect),
                  ),
                ),
              ],
            ),
            if (connectMode) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.polyline_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      copy.selectionHint(selectedCount, selectedLinkType),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(onPressed: onClear, child: Text(copy.clear)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      LinkType.values.map((type) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(linkTypeIcon(type), size: 16),
                            label: Text(linkTypeLabel(type)),
                            selected: selectedLinkType == type,
                            showCheckmark: false,
                            onSelected: (_) => onTypeChanged(type),
                          ),
                        );
                      }).toList(),
                ),
              ),
              if (selectedLinkType == LinkType.parentChild) ...[
                const SizedBox(height: 8),
                SegmentedButton<_GraphConnectPattern>(
                  segments: [
                    ButtonSegment(
                      value: _GraphConnectPattern.chain,
                      icon: const Icon(Icons.timeline_rounded),
                      label: Text(copy.chainMode),
                    ),
                    ButtonSegment(
                      value: _GraphConnectPattern.center,
                      icon: const Icon(Icons.hub_outlined),
                      label: Text(copy.centerMode),
                    ),
                  ],
                  selected: {connectPattern},
                  showSelectedIcon: false,
                  onSelectionChanged:
                      (values) => onPatternChanged(values.first),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.patternHint(connectPattern),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount >= 2 ? onCreate : null,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(copy.bind(selectedCount, selectedLinkType)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GraphBackgroundPainter extends CustomPainter {
  _GraphBackgroundPainter({
    required this.backgroundColor,
    required this.gridColor,
    required this.centerColor,
  });

  final Color backgroundColor;
  final Color gridColor;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final finePaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.22)
          ..strokeWidth = 1;
    final boldPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.42)
          ..strokeWidth = 1.2;

    for (double x = 0; x <= size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), finePaint);
    }
    for (double y = 0; y <= size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), finePaint);
    }
    for (double x = 0; x <= size.width; x += 400) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), boldPaint);
    }
    for (double y = 0; y <= size.height; y += 400) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), boldPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      5,
      Paint()..color = centerColor.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _GraphBackgroundPainter oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor ||
      gridColor != oldDelegate.gridColor ||
      centerColor != oldDelegate.centerColor;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.positions,
    required this.links,
    required this.idToIndex,
    required this.linkColor,
  });

  final List<Offset> positions;
  final List<InspirationLink> links;
  final Map<int, int> idToIndex;
  final Color Function(LinkType) linkColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final si = idToIndex[link.sourceId];
      final ti = idToIndex[link.targetId];
      if (si == null || ti == null) continue;
      final start = positions[si];
      final end = positions[ti];
      final color = linkColor(link.linkType);
      final direction = end - start;
      if (direction.distance < 1) continue;
      final normal = Offset(-direction.dy, direction.dx) / direction.distance;
      final isParentChild = link.linkType == LinkType.parentChild;
      final control = (start + end) / 2 + normal * (isParentChild ? 8 : 28);
      final path =
          Path()
            ..moveTo(start.dx, start.dy)
            ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final shadowPaint =
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08)
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
      final linePaint =
          Paint()
            ..color = color.withValues(alpha: link.isAutoGenerated ? 0.48 : 0.8)
            ..strokeWidth =
                isParentChild ? 3.4 : (link.confidence * 3.2).clamp(1.4, 4.0)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, shadowPaint);
      if (isParentChild) {
        _drawSolidPath(canvas, path, linePaint);
      } else {
        canvas.drawPath(path, linePaint);
      }

      final midpoint = _quadraticPoint(start, control, end, 0.5);
      canvas.drawCircle(
        midpoint,
        4,
        Paint()..color = color.withValues(alpha: 0.86),
      );
      if (isParentChild) {
        _drawArrowHead(
          canvas,
          _quadraticPoint(start, control, end, 0.72),
          end,
          color,
        );
      }
    }
  }

  void _drawSolidPath(Canvas canvas, Path path, Paint paint) {
    canvas.drawPath(path, paint);
  }

  void _drawArrowHead(Canvas canvas, Offset nearEnd, Offset end, Color color) {
    final direction = end - nearEnd;
    if (direction.distance < 1) return;
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final tip = end - unit * 18;
    final left = tip - unit * 15 + normal * 8;
    final right = tip - unit * 15 - normal * 8;
    final path =
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(right.dx, right.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final oneMinusT = 1 - t;
    return p0 * oneMinusT * oneMinusT + p1 * 2 * oneMinusT * t + p2 * t * t;
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}

class _SelectionPathPainter extends CustomPainter {
  _SelectionPathPainter({
    required this.positions,
    required this.selectedIds,
    required this.idToIndex,
    required this.color,
  });

  final List<Offset> positions;
  final List<int> selectedIds;
  final Map<int, int> idToIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIds.length < 2) return;
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.72)
          ..strokeWidth = 3.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < selectedIds.length - 1; i++) {
      final startIndex = idToIndex[selectedIds[i]];
      final endIndex = idToIndex[selectedIds[i + 1]];
      if (startIndex == null || endIndex == null) continue;
      final start = positions[startIndex];
      final end = positions[endIndex];
      final dashVector = end - start;
      final distance = dashVector.distance;
      if (distance <= 0) continue;
      final direction = dashVector / distance;
      var cursor = 0.0;
      while (cursor < distance) {
        final dashEnd = min(cursor + 18, distance);
        canvas.drawLine(
          start + direction * cursor,
          start + direction * dashEnd,
          paint,
        );
        cursor += 30;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPathPainter oldDelegate) => true;
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({
    required this.inspiration,
    required this.width,
    required this.maxHeight,
    required this.selected,
    required this.hovered,
    required this.connectMode,
    required this.accentColor,
    required this.selectionIndex,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHoverChanged,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Inspiration inspiration;
  final double width;
  final double maxHeight;
  final bool selected;
  final bool hovered;
  final bool connectMode;
  final Color accentColor;
  final int selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<bool> onHoverChanged;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview =
        inspiration.content.length > 72
            ? '${inspiration.content.substring(0, 72)}...'
            : inspiration.content;
    final hasSource =
        inspiration.source != null && inspiration.source!.trim().isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.94)
                    : theme.colorScheme.surfaceContainerHigh.withValues(
                      alpha: hovered ? 1 : 0.96,
                    ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : accentColor.withValues(alpha: hovered ? 0.74 : 0.42),
              width:
                  selected
                      ? 2.2
                      : hovered
                      ? 1.4
                      : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(
                  alpha:
                      selected
                          ? 0.22
                          : hovered
                          ? 0.18
                          : 0.12,
                ),
                blurRadius:
                    selected
                        ? 28
                        : hovered
                        ? 22
                        : 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSource || connectMode) ...[
                    Row(
                      children: [
                        if (hasSource) ...[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              SourceMapper.displayName(
                                context,
                                inspiration.source!,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (connectMode)
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color:
                                selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (inspiration.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      inspiration.tags.take(2).map((t) => '#$t').join('  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${selectionIndex + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphCopy {
  const _GraphCopy({required this.isZh});
  _GraphCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get connect => isZh ? '串联灵感' : 'Link ideas';
  String get exitConnect => isZh ? '退出串联' : 'Exit';
  String get fitView => isZh ? '适配视图' : 'Fit view';
  String get resetLayout => isZh ? '重新布局' : 'Reset layout';
  String get clear => isZh ? '清空' : 'Clear';
  String get undo => isZh ? '撤销' : 'Undo';
  String get idea => isZh ? '灵感' : 'Idea';
  String get openIdea => isZh ? '打开灵感' : 'Open idea';
  String get chainMode => isZh ? '链式' : 'Chain';
  String get centerMode => isZh ? '中心' : 'Center';

  String nodes(int count) => isZh ? '$count 个灵感' : '$count ideas';
  String links(int count) => isZh ? '$count 条关系' : '$count links';

  String selectionHint(int count, LinkType type) {
    if (isZh) {
      if (type == LinkType.parentChild) {
        return count < 2
            ? '按父 → 子 → 孙的顺序点击灵感'
            : '已选择 $count 个灵感，将按父 → 子方向设置/解除层级';
      }
      return count < 2 ? '按顺序点击 2 个或多个灵感，生成一条串联关系' : '已选择 $count 个灵感，将按点击顺序串联';
    }
    if (type == LinkType.parentChild) {
      return count < 2
          ? 'Tap ideas in parent -> child order'
          : '$count ideas selected in parent -> child order.';
    }
    return count < 2
        ? 'Tap 2 or more ideas in order to create a chain'
        : '$count ideas selected. They will be linked in tap order.';
  }

  String bind(int count, LinkType type) {
    if (isZh) {
      if (count < 2) return '至少选择 2 个灵感';
      return type == LinkType.parentChild ? '按父→子顺序设置/解除' : '绑定 $count 个灵感';
    }
    if (count < 2) return 'Select at least 2 ideas';
    return type == LinkType.parentChild
        ? 'Set/remove hierarchy'
        : 'Bind $count ideas';
  }

  String patternHint(_GraphConnectPattern pattern) {
    if (isZh) {
      return pattern == _GraphConnectPattern.center
          ? '第一个灵感作为上级，后续选中的灵感都作为下级'
          : '按点击顺序生成 A → B → C 的层级链';
    }
    return pattern == _GraphConnectPattern.center
        ? 'First selected idea is the parent; all following ideas become children'
        : 'Creates a hierarchy chain in tap order: A -> B -> C';
  }

  String linkResult(
    int createdCount,
    int skippedCount,
    int removedCount,
    int cycleCount,
    bool isParentChild,
  ) {
    if (isZh) {
      if (isParentChild) {
        final parts = [
          if (createdCount > 0) '新增 $createdCount 条父子关系',
          if (removedCount > 0) '解除 $removedCount 条父子关系',
          if (cycleCount > 0) '跳过 $cycleCount 条成环关系',
          if (skippedCount > 0) '跳过 $skippedCount 条重复关系',
        ];
        return parts.isEmpty ? '没有可处理的父子关系' : parts.join('，');
      }
      if (createdCount == 0 && skippedCount > 0) return '这些关系已经存在';
      return '已创建 $createdCount 条关系'
          '${skippedCount > 0 ? '，跳过 $skippedCount 条重复关系' : ''}';
    }
    if (isParentChild) {
      final parts = [
        if (createdCount > 0) 'Added $createdCount hierarchy links',
        if (removedCount > 0) 'Removed $removedCount hierarchy links',
        if (cycleCount > 0) 'Skipped $cycleCount cyclic links',
        if (skippedCount > 0) 'Skipped $skippedCount duplicates',
      ];
      return parts.isEmpty ? 'No hierarchy changes' : parts.join(', ');
    }
    if (createdCount == 0 && skippedCount > 0) {
      return 'These links already exist';
    }
    return 'Created $createdCount links'
        '${skippedCount > 0 ? ', skipped $skippedCount duplicates' : ''}';
  }
}
