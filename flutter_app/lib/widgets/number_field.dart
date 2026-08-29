import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// حقل رقمي بيبدأ بصفر افتراضيًا (زي ZeroDefaultMixin في الباك إند).
/// لو المستخدم سابه فاضي بيرجع صفر.
class NumberField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool allowDecimal;
  final int flex;
  final bool dense;
  final VoidCallback? onChanged;

  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.allowDecimal = false,
    this.flex = 1,
    this.dense = false,
    this.onChanged,
  });

  factory NumberField.zero({
    required String label,
    bool allowDecimal = false,
    VoidCallback? onChanged,
  }) {
    return NumberField(
      label: label,
      controller: TextEditingController(text: "0"),
      allowDecimal: allowDecimal,
      onChanged: onChanged,
    );
  }

  /// القيمة الرقمية الحالية (فاضي => 0)
  num value() {
    final t = controller.text.trim();
    if (t.isEmpty) return 0;
    return num.tryParse(t) ?? 0;
  }

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _c = widget.controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _c,
      textAlign: widget.dense ? TextAlign.center : TextAlign.start,
      style: widget.dense ? const TextStyle(fontSize: 13) : null,
      decoration: widget.dense
          ? const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(),
            )
          : InputDecoration(labelText: widget.label),
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(widget.allowDecimal ? r"^\d*\.?\d{0,2}" : r"^\d+"),
        ),
      ],
      onTap: () {
        // أول لمسة تختار الصفر كله عشان الكتابة تبدأ مباشرة
        if (_c.text == "0") {
          _c.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
        }
      },
      onChanged: (t) {
        if (t.trim().isEmpty) _c.text = "0";
        widget.onChanged?.call();
      },
    );
  }
}