import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/services/location_service.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../l10n/l10n_extensions.dart';
import '../models/location_model.dart';
import 'location_picker_widget.dart';

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String mapPickerTitle;
  final IconData icon;
  final Color iconColor;
  final LocationModel? initialLocation;
  final ValueChanged<LocationModel?> onLocationSelected;
  final LocationService? locationService;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.mapPickerTitle,
    required this.icon,
    required this.iconColor,
    required this.onLocationSelected,
    this.initialLocation,
    this.locationService,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  final String _sessionToken = const Uuid().v4();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _isLoading = false;
  bool _showFallback = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onLocationSelected(null);
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _showFallback = false;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 280), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    setState(() {
      _isLoading = true;
      _showFallback = false;
    });

    try {
      final result = await _locationService.autocomplete(
        query: query,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = result.suggestions;
        _showFallback = result.suggestions.isEmpty;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _showFallback = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.placeDetail(
        placeId: suggestion.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      widget.controller.text = location.name;
      widget.onLocationSelected(location);
      setState(() {
        _suggestions = const [];
        _showFallback = false;
        _isLoading = false;
      });
      FocusScope.of(context).unfocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showFallback = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openMapPicker() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: widget.mapPickerTitle,
          initialLocation: widget.initialLocation,
          onLocationSelected: (_) {},
        ),
      ),
    );

    if (location == null || !mounted) return;
    widget.controller.text = location.name;
    widget.onLocationSelected(location);
    setState(() {
      _suggestions = const [];
      _showFallback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            color: T.onSurface(context),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: T.surface(context),
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: widget.iconColor),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: context.l10n.locationPickOnMap,
                    icon: const Icon(Icons.map_outlined),
                    onPressed: _openMapPicker,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: T.outline(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: T.outline(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: T.primary(context), width: 2),
            ),
          ),
          validator: (value) =>
              widget.initialLocation == null && (value == null || value.isEmpty)
              ? context.l10n.requiredWord
              : null,
        ),
        if (_suggestions.isNotEmpty) _buildSuggestions(),
        if (_showFallback) _buildFallback(),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Material(
        color: T.surface(context),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: T.outline(context)),
        ),
        child: Column(
          children: _suggestions.take(5).map((suggestion) {
            return ListTile(
              dense: true,
              leading: Icon(Icons.place_outlined, color: T.primary(context)),
              title: Text(
                suggestion.primaryText.isNotEmpty
                    ? suggestion.primaryText
                    : suggestion.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: suggestion.secondaryText.isEmpty
                  ? null
                  : Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => _selectSuggestion(suggestion),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.locationSearchNoResults,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _openMapPicker,
            icon: const Icon(Icons.map_outlined),
            label: Text(context.l10n.locationPickOnMap),
          ),
        ],
      ),
    );
  }
}
