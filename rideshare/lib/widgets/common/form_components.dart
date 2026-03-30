import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/colors.dart';

class ModernInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;

  const ModernInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.suffixIcon,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      textField: true,
      child: Container(
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(
            fontSize: 16,
            color: enabled ? T.onSurface(context) : T.onSurfaceVariant(context),
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(
              color: T.onSurfaceVariant(context).withValues(alpha: 0.5),
              fontSize: 14,
            ),
            labelStyle: TextStyle(
              color: T.onSurfaceVariant(context),
              fontSize: 14,
            ),
            prefixIcon: _buildPrefixIcon(context),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: T.surface(context),
            border: _buildInputBorder(
              T.outline(context).withValues(alpha: 0.5),
            ),
            enabledBorder: _buildInputBorder(
              T.outline(context).withValues(alpha: 0.5),
            ),
            focusedBorder: _buildInputBorder(T.primary(context), width: 2),
            errorBorder: _buildInputBorder(T.error(context)),
            focusedErrorBorder: _buildInputBorder(T.error(context), width: 2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
          validator: validator,
        ),
      ),
    );
  }

  Widget _buildPrefixIcon(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: T.primary(context), size: 20),
    );
  }

  OutlineInputBorder _buildInputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class ModernSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isVertical;

  const ModernSelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.subtitle,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return _buildVerticalCard(context);
    }
    return _buildHorizontalCard(context);
  }

  Widget _buildVerticalCard(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: MergeSemantics(
          child: Tooltip(
            message: title,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: _buildCardDecoration(context),
              child: Column(
                children: [
                  _buildIconContainer(),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : T.onSurface(context),
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        IconsaxPlusBold.tick_circle,
                        size: 18,
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: MergeSemantics(
          child: Tooltip(
            message: title,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: _buildCardDecoration(context),
              child: Row(
                children: [
                  _buildIconContainer(borderRadius: 12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : T.onSurface(context),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildCheckIndicator(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: isSelected ? color.withValues(alpha: 0.08) : T.surface(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isSelected ? color : T.outline(context),
        width: isSelected ? 2 : 1,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  Widget _buildIconContainer({double borderRadius = 100}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, size: 24, color: isSelected ? AppColors.white : color),
    );
  }

  Widget _buildCheckIndicator(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? color : AppColors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? color : T.outline(context),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: AppColors.white)
          : null,
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final IconData? trailingIcon;
  final Color? color;

  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.trailingIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? T.primary(context);
    final shadowColor = buttonColor.withValues(alpha: 0.35);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color != null ? buttonColor : null,
        gradient: color == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [T.primary(context), AppColors.teal700],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Semantics(
        button: true,
        label: text,
        enabled: onPressed != null,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.transparent,
            shadowColor: AppColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading ? _buildLoadingIndicator() : _buildButtonContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
      ),
    );
  }

  Widget _buildButtonContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            letterSpacing: 0.5,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, color: AppColors.white, size: 20),
        ],
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const InfoCard({
    super.key,
    required this.message,
    this.color = AppColors.info,
    this.icon = IconsaxPlusLinear.info_circle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final bool isRequired;

  const SectionTitle({super.key, required this.title, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.onSurface(context),
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: T.error(context),
            ),
          ),
      ],
    );
  }
}
