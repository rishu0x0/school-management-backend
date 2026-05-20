import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_attendance/features/classes/notifier/classes_notifier.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';

class ClassFormSheet extends ConsumerStatefulWidget {
  const ClassFormSheet({super.key, this.editClass});
  final ClassModel? editClass;

  @override
  ConsumerState<ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends ConsumerState<ClassFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _subjectCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.editClass != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editClass?.name ?? '');
    _sectionCtrl = TextEditingController(text: widget.editClass?.section ?? '');
    _subjectCtrl = TextEditingController(text: widget.editClass?.subject ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sectionCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifier = ref.read(classesNotifierProvider.notifier);
      if (_isEdit) {
        await notifier.updateClass(
          classID: widget.editClass!.id,
          name: _nameCtrl.text.trim(),
        );
      } else {
        await notifier.create(
          name: _nameCtrl.text.trim(),
          section: _sectionCtrl.text.trim(),
          subject: _subjectCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit Class' : 'New Class',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Class name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Class name is required' : null,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _sectionCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Create Class'),
            ),
          ],
        ),
      ),
    );
  }
}
