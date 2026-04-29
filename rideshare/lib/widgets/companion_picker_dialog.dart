import 'package:flutter/material.dart';

/// Data for one passenger seat in a multi-seat booking.
class CompanionSeatData {
  String displayName;
  String gender; // 'male' | 'female'
  bool isMainBooker;

  CompanionSeatData({
    required this.displayName,
    required this.gender,
    this.isMainBooker = false,
  });
}

/// Dialog that lets the user enter companion passenger info before booking
/// multiple seats.
///
/// Usage:
/// ```dart
/// final result = await showDialog<List<CompanionSeatData>>(
///   context: context,
///   builder: (_) => CompanionPickerDialog(mainBookerName: 'Ahmed', mainBookerGender: 'male', extraSeats: 2),
/// );
/// ```
///
/// Returns null if the user dismissed, or a list whose first item is the main
/// booker and the rest are companions (in order).
///
/// Phase 4 / T083 — 008-platform-completion.
class CompanionPickerDialog extends StatefulWidget {
  /// Display name of the main booker (pre-filled, read-only).
  final String mainBookerName;

  /// Gender of the main booker ('male' | 'female').
  final String mainBookerGender;

  /// Number of additional companion seats (1–5).
  final int extraSeats;

  const CompanionPickerDialog({
    super.key,
    required this.mainBookerName,
    required this.mainBookerGender,
    required this.extraSeats,
  });

  @override
  State<CompanionPickerDialog> createState() => _CompanionPickerDialogState();
}

class _CompanionPickerDialogState extends State<CompanionPickerDialog> {
  late final List<CompanionSeatData> _companions;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _companions = List.generate(
      widget.extraSeats,
      (_) => CompanionSeatData(displayName: '', gender: widget.mainBookerGender),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('بيانات المرافقين'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main booker row (read-only)
                _SeatRow(
                  label: 'الحاجز الرئيسي',
                  name: widget.mainBookerName,
                  gender: widget.mainBookerGender,
                  readOnly: true,
                  onChanged: (_, __) {},
                ),
                const Divider(),
                // Companion rows
                ...List.generate(widget.extraSeats, (i) {
                  return _SeatRow(
                    label: 'مرافق ${i + 1}',
                    name: _companions[i].displayName,
                    gender: _companions[i].gender,
                    onChanged: (name, gender) {
                      _companions[i].displayName = name;
                      _companions[i].gender = gender;
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حجز'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final result = <CompanionSeatData>[
      CompanionSeatData(
        displayName: widget.mainBookerName,
        gender: widget.mainBookerGender,
        isMainBooker: true,
      ),
      ..._companions,
    ];
    Navigator.of(context).pop(result);
  }
}

class _SeatRow extends StatefulWidget {
  final String label;
  final String name;
  final String gender;
  final bool readOnly;
  final void Function(String name, String gender) onChanged;

  const _SeatRow({
    required this.label,
    required this.name,
    required this.gender,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<_SeatRow> createState() => _SeatRowState();
}

class _SeatRowState extends State<_SeatRow> {
  late String _gender;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;
    _nameCtrl = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextFormField(
            controller: _nameCtrl,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            validator: widget.readOnly
                ? null
                : (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            onSaved: (v) => widget.onChanged(v?.trim() ?? '', _gender),
          ),
          const SizedBox(height: 6),
          if (!widget.readOnly)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('ذكر')),
                ButtonSegment(value: 'female', label: Text('أنثى')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) {
                setState(() => _gender = s.first);
                widget.onChanged(_nameCtrl.text, _gender);
              },
            ),
        ],
      ),
    );
  }
}
