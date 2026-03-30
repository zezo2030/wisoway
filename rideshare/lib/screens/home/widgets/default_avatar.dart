import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';

class DefaultAvatar extends StatelessWidget {
  const DefaultAvatar({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(IconsaxPlusBold.profile, color: AppColors.white, size: size);
  }
}
