import 'package:flutter/material.dart';
import '../utils/phone_formatter.dart';

/// Renders a phone number in left-to-right reading order regardless of the
/// surrounding text direction. Use everywhere a stored E.164 (or local) phone
/// number is shown to the user.
class PhoneText extends StatelessWidget {
  final String? raw;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PhoneText(
    this.raw, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        formatPhoneDisplay(raw),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
