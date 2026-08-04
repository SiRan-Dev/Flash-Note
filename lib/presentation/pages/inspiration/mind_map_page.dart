import 'dart:convert';
import 'dart:math' as math;

import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flashnote/core/utils/desktop_canvas_shortcuts.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MindMapPage extends ConsumerStatefulWidget {
  const MindMapPage({
    super.key,
    required this.inspirationId,
    required this.content,
  });

  final int inspirationId;
  final String content;

  @override
  ConsumerState<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends ConsumerState<MindMapPage> {
  final _canvasKey = GlobalKey<_MindMapCanvasState>();

  MindMapNode? _root;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedOrGenerate();
  }

  Future<void> _loadCachedOrGenerate() async {
    final cached = await ref.read(
      mindMapCacheProvider(widget.inspirationId).future,
    );
    if (cached != null && mounted) {
      setState(() => _root = cached);
      return;
    }
    _generate();
  }

  Future<void> _generate() async {
    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(aiServiceProvider);
      final result = await service.generateMindMap(
        widget.content,
        preset,
        apiKey,
      );
      if (!mounted) return;
      setState(() {
        _root = result;
        _isLoading = false;
      });
      await ref
          .read(inspirationRepositoryProvider)
          .updateMindMapData(widget.inspirationId, jsonEncode(result.toJson()));
      ref.invalidate(mindMapCacheProvider(widget.inspirationId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).mindMapError;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    await ref
        .read(inspirationRepositoryProvider)
        .updateMindMapData(widget.inspirationId, null);
    ref.invalidate(mindMapCacheProvider(widget.inspirationId));
    if (!mounted) return;
    setState(() => _root = null);
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.mindMap),
      ),
      body:
          _isLoading
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _MindMapStateView(
                    icon: Icons.hub_outlined,
                    title: l10n.generatingMindMap,
                    subtitle: _MindMapCopy.of(context).loadingSubtitle,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              )
              : _error != null
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _MindMapStateView(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    subtitle: _MindMapCopy.of(context).errorSubtitle,
                    accentColor: theme.colorScheme.error,
                    child: FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.reanalyze),
                    ),
                  ),
                ),
              )
              : _root == null
              ? const SizedBox.shrink()
              : Stack(
                children: [
                  Positioned.fill(
                    child: _MindMapCanvas(
                      key: _canvasKey,
                      root: _root!,
                      colorScheme: theme.colorScheme,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: _MindMapHud(
                      stats: _MindMapStats.fromRoot(_root!),
                      copy: _MindMapCopy.of(context),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _MindMapToolbar(
                      copy: _MindMapCopy.of(context),
                      onFitView: () => _canvasKey.currentState?.fitView(),
                      onRefresh: _generate,
                      onClear: _clearCache,
                    ),
                  ),
                ],
              ),
    );
  }
}

class _MindMapStateView extends StatelessWidget {
  const _MindMapStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          borderColor: accent.withValues(alpha: 0.26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppAccentPalette.tintSurfaceStrong(
                    theme.colorScheme,
                    accent,
                    amount: 0.26,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MindMapHud extends StatelessWidget {
  const _MindMapHud({required this.stats, required this.copy});

  final _MindMapStats stats;
  final _MindMapCopy copy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final metrics = [
            AppMetricChip(
              icon: Icons.hub_outlined,
              label: copy.nodes(stats.nodeCount),
            ),
            AppMetricChip(
              icon: Icons.account_tree_outlined,
              label: copy.branches(stats.branchCount),
            ),
            AppMetricChip(
              icon: Icons.layers_outlined,
              label: copy.depth(stats.maxDepth),
            ),
          ];

          return AppPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child:
                compact
                    ? Wrap(spacing: 8, runSpacing: 8, children: metrics)
                    : Row(
                      children: [
                        metrics[0],
                        const SizedBox(width: 8),
                        metrics[1],
                        const SizedBox(width: 8),
                        metrics[2],
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _MindMapToolbar extends StatelessWidget {
  const _MindMapToolbar({
    required this.copy,
    required this.onFitView,
    required this.onRefresh,
    required this.onClear,
  });

  final _MindMapCopy copy;
  final VoidCallback onFitView;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

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
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onFitView,
              tooltip: copy.fitView,
              icon: const Icon(Icons.center_focus_strong_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onClear,
              tooltip: copy.reset,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(copy.regenerate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindMapCanvas extends StatefulWidget {
  const _MindMapCanvas({
    super.key,
    required this.root,
    required this.colorScheme,
  });

  final MindMapNode root;
  final ColorScheme colorScheme;

  @override
  State<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<_MindMapCanvas> {
  final TransformationController _controller = TransformationController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'mind-map-canvas');

  Size _contentSize = Size.zero;
  Size _viewportSize = Size.zero;
  bool _needsFit = true;
  bool _middlePanning = false;
  Offset? _lastPanGlobal;
  Offset? _hoverPosition;

  @override
  void didUpdateWidget(covariant _MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root != widget.root) {
      _needsFit = true;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void fitView() {
    if (_contentSize == Size.zero || _viewportSize == Size.zero) return;
    final horizontal = (_viewportSize.width - 32) / _contentSize.width;
    final vertical = (_viewportSize.height - 32) / _contentSize.height;
    final scale = math.min(horizontal, vertical).clamp(0.18, 1.4);
    final dx = (_viewportSize.width - _contentSize.width * scale) / 2;
    final dy = (_viewportSize.height - _contentSize.height * scale) / 2;
    _controller.value =
        Matrix4.identity()
          ..translateByDouble(dx, dy, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomBy(double factor) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.12, 4.0);
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final sceneCenter = _controller.toScene(center);
    final matrix =
        Matrix4.identity()
          ..translateByDouble(center.dx, center.dy, 0, 1)
          ..scaleByDouble(targetScale, targetScale, 1, 1)
          ..translateByDouble(-sceneCenter.dx, -sceneCenter.dy, 0, 1);
    _controller.value = matrix;
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
    _controller.value =
        _controller.value.clone()..translateByDouble(delta.dx, delta.dy, 0, 1);
  }

  void _endMiddlePan([PointerEvent? _]) {
    _middlePanning = false;
    _lastPanGlobal = null;
  }

  void _showContextMenu(Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final copy = _MindMapCopy.of(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(value: 'fit', child: Text(copy.fitView)),
        PopupMenuItem<String>(value: 'regen', child: Text(copy.regenerate)),
        PopupMenuItem<String>(value: 'reset', child: Text(copy.reset)),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      switch (value) {
        case 'fit':
          fitView();
        case 'regen':
          final state = context.findAncestorStateOfType<_MindMapPageState>();
          state?._generate();
        case 'reset':
          final state = context.findAncestorStateOfType<_MindMapPageState>();
          state?._clearCache();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = _OrganicMindMapLayout(widget.root, widget.colorScheme);

    return LayoutBuilder(
      builder: (context, constraints) {
        _contentSize = layout.size;
        _viewportSize = constraints.biggest;
        if (_needsFit &&
            constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            fitView();
            _needsFit = false;
          });
        }

        return CallbackShortcuts(
          bindings: {
            DesktopCanvasShortcuts.fitView: fitView,
            DesktopCanvasShortcuts.zoomIn: () => _zoomBy(1.12),
            DesktopCanvasShortcuts.zoomOut: () => _zoomBy(1 / 1.12),
          },
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: MouseRegion(
              cursor:
                  _middlePanning
                      ? SystemMouseCursors.move
                      : SystemMouseCursors.grab,
              onHover:
                  (event) =>
                      setState(() => _hoverPosition = event.localPosition),
              onExit: (_) => setState(() => _hoverPosition = null),
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
                child: InteractiveViewer(
                  transformationController: _controller,
                  boundaryMargin: const EdgeInsets.all(1200),
                  minScale: 0.12,
                  maxScale: 4.0,
                  trackpadScrollCausesScale: true,
                  scaleFactor: 180,
                  constrained: false,
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: CustomPaint(
                      painter: _MindMapPainter(
                        layout: layout,
                        colorScheme: widget.colorScheme,
                        hoverPosition:
                            _hoverPosition == null
                                ? null
                                : _controller.toScene(_hoverPosition!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrganicMindMapLayout {
  _OrganicMindMapLayout(this.root, this.colorScheme) {
    _measureBranchWeights(root);
    final rootGeometry = _geometryFor(root, 0);
    nodeGeometry[root] = rootGeometry;
    positions[root] = Offset.zero;
    parentOf[root] = null;
    branchIndex[root] = -1;

    if (root.children.isNotEmpty) {
      final totalWeight = root.children.fold<double>(
        0,
        (sum, child) => sum + branchWeight[child]!,
      );
      var cursor = -math.pi;
      for (var i = 0; i < root.children.length; i++) {
        final child = root.children[i];
        final sector = math.pi * 2 * (branchWeight[child]! / totalWeight);
        _placeNode(
          child,
          parent: root,
          depth: 1,
          branch: i,
          angle: cursor + sector / 2,
          sector: sector * 0.88,
        );
        cursor += sector;
      }
    }

    _resolveCollisions();
    _normalizePositions();
  }

  final MindMapNode root;
  final ColorScheme colorScheme;
  final Map<MindMapNode, Offset> positions = {};
  final Map<MindMapNode, _NodeGeometry> nodeGeometry = {};
  final Map<MindMapNode, double> branchWeight = {};
  final Map<MindMapNode, MindMapNode?> parentOf = {};
  final Map<MindMapNode, int> branchIndex = {};
  Size size = Size.zero;

  double _measureBranchWeights(MindMapNode node) {
    if (node.children.isEmpty) {
      branchWeight[node] = 1;
      return 1;
    }
    final childWeight = node.children.fold<double>(
      0,
      (sum, child) => sum + _measureBranchWeights(child),
    );
    final weight = math.max(1.0, childWeight + node.children.length * 0.32);
    branchWeight[node] = weight;
    return weight;
  }

  void _placeNode(
    MindMapNode node, {
    required MindMapNode parent,
    required int depth,
    required int branch,
    required double angle,
    required double sector,
  }) {
    final geometry = _geometryFor(node, depth);
    final parentPosition = positions[parent]!;
    final distance = _distanceFor(depth, geometry.size, sector);
    final offset = Offset(
      math.cos(angle) * distance,
      math.sin(angle) * distance,
    );
    positions[node] = parentPosition + offset;
    nodeGeometry[node] = geometry;
    parentOf[node] = parent;
    branchIndex[node] = branch;

    if (node.children.isEmpty) return;

    final totalWeight = node.children.fold<double>(
      0,
      (sum, child) => sum + branchWeight[child]!,
    );
    final branchSpan = math.min(math.pi * 1.08, math.max(0.8, sector * 0.84));
    var cursor = angle - branchSpan / 2;

    for (var i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final childSector = branchSpan * (branchWeight[child]! / totalWeight);
      final nudge = _nudgeForIndex(i, node.children.length, childSector);
      _placeNode(
        child,
        parent: node,
        depth: depth + 1,
        branch: branch,
        angle: cursor + childSector / 2 + nudge,
        sector: childSector,
      );
      cursor += childSector;
    }
  }

  _NodeGeometry _geometryFor(MindMapNode node, int depth) {
    final runeCount = node.label.runes.length;
    final minWidth =
        depth == 0
            ? 220.0
            : depth == 1
            ? 180.0
            : 150.0;
    final maxWidth =
        depth == 0
            ? 280.0
            : depth == 1
            ? 232.0
            : 208.0;
    final widthFactor =
        depth == 0
            ? 14.0
            : depth == 1
            ? 11.8
            : 10.4;
    final width = (runeCount * widthFactor + 60).clamp(minWidth, maxWidth);
    final height = switch (depth) {
      0 => runeCount > 12 ? 86.0 : 78.0,
      1 => runeCount > 18 ? 72.0 : 64.0,
      _ => runeCount > 18 ? 66.0 : 58.0,
    };
    return _NodeGeometry(size: Size(width, height), depth: depth);
  }

  double _distanceFor(int depth, Size nodeSize, double sector) {
    final base = depth == 1 ? 244.0 : 184.0 + depth * 18.0;
    final widthBoost = nodeSize.width * 0.2;
    final sectorBoost = (1 / math.max(sector, 0.4)) * 18;
    return base + widthBoost + sectorBoost;
  }

  double _nudgeForIndex(int index, int count, double sector) {
    if (count <= 1) return 0;
    final centered = index - (count - 1) / 2;
    return centered * math.min(0.055, sector * 0.08);
  }

  void _resolveCollisions() {
    for (var iteration = 0; iteration < 12; iteration++) {
      var movedAny = false;
      final nodes =
          positions.keys.where((node) => node != root).toList()..sort((a, b) {
            return nodeGeometry[a]!.depth.compareTo(nodeGeometry[b]!.depth);
          });

      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          final depthA = nodeGeometry[a]!.depth;
          final depthB = nodeGeometry[b]!.depth;
          if ((depthA - depthB).abs() > 1) continue;
          if (_isAncestor(a, b) || _isAncestor(b, a)) continue;

          final rectA = _rectFor(a).inflate(_collisionPaddingFor(a));
          final rectB = _rectFor(b).inflate(_collisionPaddingFor(b));
          if (!rectA.overlaps(rectB)) continue;

          final overlapX =
              math.min(rectA.right, rectB.right) -
              math.max(rectA.left, rectB.left);
          final overlapY =
              math.min(rectA.bottom, rectB.bottom) -
              math.max(rectA.top, rectB.top);
          if (overlapX <= 0 || overlapY <= 0) continue;

          final vector = _separationVector(a, b);
          final pushDistance = math.max(overlapX, overlapY) / 2 + 12;
          final delta = vector * pushDistance;

          if (depthA == depthB) {
            _moveSubtree(a, delta * -0.5);
            _moveSubtree(b, delta * 0.5);
          } else if (depthA < depthB) {
            _moveSubtree(b, delta);
          } else {
            _moveSubtree(a, delta * -1);
          }
          movedAny = true;
        }
      }

      if (!movedAny) return;
    }
  }

  Rect _rectFor(MindMapNode node) {
    final position = positions[node]!;
    final geometry = nodeGeometry[node]!;
    return Rect.fromCenter(
      center: position,
      width: geometry.size.width,
      height: geometry.size.height,
    );
  }

  double _collisionPaddingFor(MindMapNode node) {
    final depth = nodeGeometry[node]!.depth;
    return depth == 0
        ? 24
        : depth == 1
        ? 18
        : 14;
  }

  bool _isAncestor(MindMapNode ancestor, MindMapNode node) {
    var current = parentOf[node];
    while (current != null) {
      if (current == ancestor) return true;
      current = parentOf[current];
    }
    return false;
  }

  Offset _separationVector(MindMapNode a, MindMapNode b) {
    final direction = positions[b]! - positions[a]!;
    if (direction.distance > 0.01) {
      return direction / direction.distance;
    }

    final radial =
        positions[a]! - (positions[parentOf[a] ?? root] ?? Offset.zero);
    if (radial.distance > 0.01) {
      final perpendicular = Offset(-radial.dy, radial.dx);
      return perpendicular / perpendicular.distance;
    }
    return const Offset(1, 0);
  }

  void _moveSubtree(MindMapNode node, Offset delta) {
    positions[node] = positions[node]! + delta;
    for (final child in node.children) {
      _moveSubtree(child, delta);
    }
  }

  void _normalizePositions() {
    const leftPadding = 220.0;
    const rightPadding = 220.0;
    const topPadding = 320.0;
    const bottomPadding = 240.0;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    positions.forEach((node, position) {
      final size = nodeGeometry[node]!.size;
      minX = math.min(minX, position.dx - size.width / 2);
      minY = math.min(minY, position.dy - size.height / 2);
      maxX = math.max(maxX, position.dx + size.width / 2);
      maxY = math.max(maxY, position.dy + size.height / 2);
    });

    final dx = leftPadding - minX;
    final dy = topPadding - minY;
    positions.updateAll((_, value) => value.translate(dx, dy));
    size = Size(
      maxX - minX + leftPadding + rightPadding,
      maxY - minY + topPadding + bottomPadding,
    );
  }
}

class _NodeGeometry {
  const _NodeGeometry({required this.size, required this.depth});

  final Size size;
  final int depth;
}

class _MindMapPainter extends CustomPainter {
  const _MindMapPainter({
    required this.layout,
    required this.colorScheme,
    this.hoverPosition,
  });

  final _OrganicMindMapLayout layout;
  final ColorScheme colorScheme;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintConnections(canvas);
    _paintNodes(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colorScheme.surface);

    final finePaint =
        Paint()
          ..color = colorScheme.outlineVariant.withValues(alpha: 0.18)
          ..strokeWidth = 1;
    final boldPaint =
        Paint()
          ..color = colorScheme.outlineVariant.withValues(alpha: 0.34)
          ..strokeWidth = 1.1;

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
  }

  void _paintConnections(Canvas canvas) {
    for (final entry in layout.parentOf.entries) {
      final node = entry.key;
      final parent = entry.value;
      if (parent == null) continue;

      final from = layout.positions[parent]!;
      final to = layout.positions[node]!;
      final direction = to - from;
      if (direction.distance <= 1) continue;

      final parentSize = layout.nodeGeometry[parent]!.size;
      final childSize = layout.nodeGeometry[node]!.size;
      final accent = _accentFor(node);
      final angle = math.atan2(direction.dy, direction.dx);
      final start = _anchorFor(from, parentSize, angle);
      final end = _anchorFor(to, childSize, angle + math.pi);
      final controlDistance = direction.distance * 0.24;
      final path =
          Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(
              start.dx + math.cos(angle) * controlDistance,
              start.dy + math.sin(angle) * controlDistance,
              end.dx - math.cos(angle) * controlDistance,
              end.dy - math.sin(angle) * controlDistance,
              end.dx,
              end.dy,
            );

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.05)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.42)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintNodes(Canvas canvas) {
    final ordered =
        layout.positions.keys.toList()..sort(
          (a, b) => layout.nodeGeometry[a]!.depth.compareTo(
            layout.nodeGeometry[b]!.depth,
          ),
        );

    for (final node in ordered) {
      final position = layout.positions[node]!;
      final geometry = layout.nodeGeometry[node]!;
      final depth = geometry.depth;
      final hovered =
          hoverPosition != null &&
          Rect.fromCenter(
            center: position,
            width: geometry.size.width,
            height: geometry.size.height,
          ).contains(hoverPosition!);
      final accent = depth == 0 ? colorScheme.primary : _accentFor(node);
      final fill =
          depth == 0
              ? colorScheme.primaryContainer.withValues(alpha: 0.98)
              : AppAccentPalette.tintSurface(
                colorScheme,
                accent,
                amount:
                    hovered
                        ? 0.24
                        : depth == 1
                        ? 0.18
                        : 0.12,
              ).withValues(alpha: 0.98);
      final border =
          depth == 0
              ? colorScheme.primary
              : accent.withValues(alpha: hovered ? 0.72 : 0.46);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: position,
          width: geometry.size.width,
          height: geometry.size.height,
        ),
        Radius.circular(depth == 0 ? 24 : 20),
      );

      canvas.drawRRect(
        rect.shift(const Offset(0, 8)),
        Paint()
          ..color = accent.withValues(
            alpha:
                hovered
                    ? 0.18
                    : depth == 0
                    ? 0.14
                    : 0.1,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRRect(canvasClipSafe(rect), Paint()..color = fill);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = border
          ..strokeWidth = depth == 0 ? 2.2 : 1.2
          ..style = PaintingStyle.stroke,
      );

      if (depth > 0) {
        canvas.drawCircle(
          Offset(rect.left + 16, rect.top + 16),
          4.5,
          Paint()..color = accent,
        );
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color:
                depth == 0
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
            fontSize:
                depth == 0
                    ? 18
                    : depth == 1
                    ? 14
                    : 12.5,
            fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.w600,
            height: 1.24,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: depth == 0 ? 2 : 3,
        ellipsis: '...',
      )..layout(maxWidth: geometry.size.width - (depth == 0 ? 28 : 32));

      final textX = position.dx - textPainter.width / 2 + (depth > 0 ? 6 : 0);
      final textY = position.dy - textPainter.height / 2;
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  Offset _anchorFor(Offset center, Size size, double angle) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    return Offset(
      center.dx + dx * size.width * 0.42,
      center.dy + dy * size.height * 0.38,
    );
  }

  Color _accentFor(MindMapNode node) {
    final branch = layout.branchIndex[node] ?? 0;
    return AppAccentPalette.accentAt(colorScheme, branch);
  }

  @override
  bool shouldRepaint(covariant _MindMapPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.hoverPosition != hoverPosition;
  }
}

RRect canvasClipSafe(RRect rect) => rect;

class _MindMapStats {
  const _MindMapStats({
    required this.nodeCount,
    required this.branchCount,
    required this.maxDepth,
  });

  final int nodeCount;
  final int branchCount;
  final int maxDepth;

  factory _MindMapStats.fromRoot(MindMapNode root) {
    int countNodes(MindMapNode node) {
      return 1 +
          node.children.fold<int>(0, (sum, child) => sum + countNodes(child));
    }

    int depthOf(MindMapNode node) {
      if (node.children.isEmpty) return 1;
      return 1 +
          node.children.fold<int>(0, (maxDepth, child) {
            return math.max(maxDepth, depthOf(child));
          });
    }

    return _MindMapStats(
      nodeCount: countNodes(root),
      branchCount: root.children.length,
      maxDepth: depthOf(root),
    );
  }
}

class _MindMapCopy {
  const _MindMapCopy({required this.isZh});

  _MindMapCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get fitView => isZh ? '适配视图' : 'Fit view';
  String get regenerate => isZh ? '重新生成' : 'Regenerate';
  String get reset => isZh ? '清空缓存' : 'Clear cache';
  String get loadingSubtitle =>
      isZh
          ? '正在把灵感拆成更自然的主题网络。'
          : 'Turning the idea into a more organic topic map.';
  String get errorSubtitle =>
      isZh
          ? '可以重新生成，或者检查当前模型和密钥配置。'
          : 'Try again or verify the current model and API key.';

  String nodes(int count) => isZh ? '$count 个节点' : '$count nodes';
  String branches(int count) => isZh ? '$count 条主分支' : '$count branches';
  String depth(int count) => isZh ? '$count 层结构' : '$count levels';
}
