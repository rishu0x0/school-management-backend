import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';
import 'package:school_attendance/features/students/notifier/students_notifier.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';

class StudentFormSheet extends ConsumerStatefulWidget {
  const StudentFormSheet({
    super.key,
    required this.classID,
    this.editStudent,
  });

  final String classID;
  final StudentModel? editStudent;

  @override
  ConsumerState<StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends ConsumerState<StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rollCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.editStudent != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editStudent?.fullName ?? '');
    _rollCtrl = TextEditingController(
      text: widget.editStudent != null
          ? widget.editStudent!.rollNumber.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final rollText = _rollCtrl.text.trim();
    final rollNumber = rollText.isNotEmpty ? int.tryParse(rollText) : null;

    try {
      final notifier =
          ref.read(studentsNotifierProvider(widget.classID).notifier);
      if (_isEdit) {
        await notifier.updateStudent(
          studentID: widget.editStudent!.id,
          fullName: _nameCtrl.text.trim(),
          rollNumber: rollNumber,
        );
      } else {
        await notifier.create(
          fullName: _nameCtrl.text.trim(),
          rollNumber: rollNumber,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Something went wrong'; _loading = false; });
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
              _isEdit ? 'Edit Student' : 'Add Student',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rollCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Roll number (optional — auto-assigned if empty)',
                border: OutlineInputBorder(),
              ),
            ),
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
                  : Text(_isEdit ? 'Save Changes' : 'Add Student'),
            ),
          ],
        ),
      ),
    );
  }
}
