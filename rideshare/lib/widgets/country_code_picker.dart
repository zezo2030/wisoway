import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../core/constants/countries.dart';
import '../core/theme/colors.dart';

/// ويدجت لاختيار رمز الدولة مع بحث - يستخدم في حقول رقم الهاتف
class CountryCodePicker extends StatelessWidget {
  final CountryData selectedCountry;
  final ValueChanged<CountryData> onCountryChanged;
  final Color? borderColor;
  final double? width;

  const CountryCodePicker({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.borderColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor ?? AppColors.primary.withOpacity(0.3);

    return GestureDetector(
      onTap: () => _showCountryPicker(context),
      child: Container(
        width: width ?? 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: effectiveBorderColor),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _flagEmoji(selectedCountry.iso2),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selectedCountry.dialCode,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              IconsaxPlusLinear.arrow_down_2,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _flagEmoji(String iso2) {
    if (iso2.length != 2) return '🌐';
    final chars = iso2.toUpperCase().codeUnits;
    if (chars.any((c) => c < 65 || c > 90)) return '🌐';
    return String.fromCharCodes(
      chars.map((c) => 0x1F1E6 + (c - 65)),
    );
  }

  void _showCountryPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(
        selectedCountry: selectedCountry,
        onCountrySelected: (country) {
          onCountryChanged(country);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryData selectedCountry;
  final ValueChanged<CountryData> onCountrySelected;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<CountryData> _filteredCountries = Countries.all;

  @override
  void initState() {
    super.initState();
    _filteredCountries = Countries.all;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredCountries = Countries.all;
      } else {
        _filteredCountries =
            Countries.all.where((c) => c.matchesQuery(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.6;

    return Container(
      height: sheetHeight + bottomPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'اختر الدولة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _filterCountries,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رمز الدولة...',
                prefixIcon: Icon(
                  IconsaxPlusLinear.search_normal_1,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Country list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = country.dialCode == widget.selectedCountry.dialCode;

                return ListTile(
                  leading: Text(
                    _flagEmoji(country.iso2),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    country.nameAr,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${country.nameEn} ${country.dialCode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(IconsaxPlusBold.tick_circle, color: AppColors.primary)
                      : null,
                  onTap: () => widget.onCountrySelected(country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _flagEmoji(String iso2) {
    if (iso2.length != 2) return '🌐';
    final chars = iso2.toUpperCase().codeUnits;
    if (chars.any((c) => c < 65 || c > 90)) return '🌐';
    return String.fromCharCodes(
      chars.map((c) => 0x1F1E6 + (c - 65)),
    );
  }
}
