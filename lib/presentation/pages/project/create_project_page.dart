import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({
    super.key,
    this.projectId,
    this.inspirationId,
    this.initialTitle,
    this.initialDescription,
  });

  final int? projectId;
  final int? inspirationId;
  final String? initialTitle;
  final String? initialDescription;

  bool get isEditing => projectId != null;

  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (widget.isEditing) {
        _loadProject();
      }
    }
  }

  Future<void> _loadProject() async {
    setState(() => _isLoading = true);
    final repo = ref.read(projectRepositoryProvider);
    final project = await repo.getById(widget.projectId!);
    if (project != null && mounted) {
      setState(() {
        _titleController.text = project.title;
        _descriptionController.text = project.description;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(projectRepositoryProvider);

    if (widget.isEditing) {
      final original = await repo.getById(widget.projectId!);
      if (original == null) return;
      await repo.update(
        original.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
      ref.invalidate(projectListProvider);
      ref.invalidate(projectDetailProvider(widget.projectId!));
      if (mounted) context.pop(true);
    } else {
      final id = await repo.create(
        _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        inspirationId: widget.inspirationId,
      );
      ref.read(projectListProvider.notifier).refresh();
      if (mounted) context.push('/project/$id');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
        title: Text(widget.isEditing ? l10n.editProject : l10n.createProject),
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
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.projectTitle,
                          hintText: l10n.projectTitleHint,
                          border: const OutlineInputBorder(),
                        ),
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.projectTitleHint;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n.projectDescription,
                          hintText: l10n.projectDescriptionHint,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 6,
                        minLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
