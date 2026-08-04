import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/source_selector.dart';
import 'package:flashnote/presentation/widgets/tag_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key, this.editId});

  final int? editId;

  bool get isEditing => editId != null;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String? _selectedSource;
  List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadInspiration();
    }
  }

  Future<void> _loadInspiration() async {
    setState(() => _isLoading = true);
    final repo = ref.read(inspirationRepositoryProvider);
    final inspiration = await repo.getById(widget.editId!);
    if (inspiration != null && mounted) {
      setState(() {
        _contentController.text = inspiration.content;
        _selectedSource = inspiration.source;
        _tags = List.from(inspiration.tags);
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(inspirationRepositoryProvider);

    if (widget.isEditing) {
      final original = await repo.getById(widget.editId!);
      if (original == null) return;
      await repo.update(
        original.copyWith(
          content: _contentController.text.trim(),
          source: _selectedSource,
          tags: _tags,
        ),
      );
    } else {
      await repo.create(
        _contentController.text.trim(),
        source: _selectedSource,
        tags: _tags,
      );
    }

    ref.read(inspirationListProvider.notifier).refresh();
    ref.invalidate(homeRecentInspirationsProvider);

    if (mounted) context.pop(widget.isEditing);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? l10n.editInspiration : l10n.captureInspiration,
        ),
        actions: [
          FilledButton(onPressed: _save, child: Text(l10n.save)),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: l10n.writeInspiration,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 8,
                        minLines: 4,
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.contentEmpty;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.inspirationSource,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SourceSelector(
                        selectedSource: _selectedSource,
                        onSelected:
                            (source) =>
                                setState(() => _selectedSource = source),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.tags,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TagInput(
                        tags: _tags,
                        onChanged: (tags) => setState(() => _tags = tags),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
