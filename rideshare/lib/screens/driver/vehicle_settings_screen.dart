import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../models/seat_layout_config.dart';
import '../../models/vehicle_art.dart';
import '../../models/vehicle_type_template.dart';
import '../../models/vehicle_model.dart';
import '../../l10n/l10n_extensions.dart';
import '../../widgets/expandable_cabin_view.dart';
import '../../widgets/vehicle_color_dropdown.dart';

/// The driver's vehicle: its type (which fixes the seat map), colour and the
/// gender-separation rule. The seat map is the type's artwork — there is no
/// row-by-row editing; changing the type is how the layout changes.
class VehicleSettingsScreen extends StatefulWidget {
  const VehicleSettingsScreen({super.key});

  @override
  State<VehicleSettingsScreen> createState() => _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState extends State<VehicleSettingsScreen> {
  final VehicleService _vehicleService = VehicleService();

  VehicleModel? _vehicle;
  List<VehicleTypeTemplate> _vehicleTypes = const [];
  String? _selectedVehicleType;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _preventGenderMixing = false;

  /// Colour key from the colour list (or an old free-text value). Shown to
  /// passengers so they can spot the car.
  String? _color;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final vehicle = await _vehicleService.getMyVehicle();
      var vehicleTypes = <VehicleTypeTemplate>[];
      try {
        vehicleTypes = await _vehicleService.getVehicleTypes();
      } catch (_) {
        vehicleTypes = await _vehicleService.getCachedVehicleTypes();
      }
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        _vehicleTypes = vehicleTypes;
        _selectedVehicleType = vehicle?.vehicleType;
        _color = vehicle?.color;
        _preventGenderMixing =
            vehicle?.seatLayout?.preventGenderMixing ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  VehicleTypeTemplate? get _currentTemplate =>
      _templateForType(_selectedVehicleType ?? _vehicle?.vehicleType);

  VehicleTypeTemplate? _templateForType(String? type) {
    if (type == null || type.isEmpty) return null;
    for (final template in _vehicleTypes) {
      if (template.type == type) return template;
    }
    return null;
  }

  /// The type's own layout; a vehicle whose type has no template keeps the
  /// layout it was registered with.
  SeatLayoutConfig? get _layout {
    final base = _currentTemplate?.layout ?? _vehicle?.seatLayout;
    return base?.copyWith(preventGenderMixing: _preventGenderMixing);
  }

  int get _seatCount => _currentTemplate?.seats ?? _vehicle?.seats ?? 0;

  /// Artwork for the selected type, when it matches that type's seat count.
  VehicleArt? get _art {
    final art = vehicleArtFor(_selectedVehicleType ?? _vehicle?.vehicleType);
    return art != null && art.seatCount == _seatCount ? art : null;
  }

  Future<void> _save() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = await _vehicleService.updateVehicle(
        vehicle.id,
        vehicleType: _selectedVehicleType,
        color: _color?.trim(),
        seats: _currentTemplate?.seats,
        seatLayout: _layout,
      );
      if (!mounted) return;
      setState(() => _vehicle = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: T.success(context),
          content: Text(
            context.l10n.seatLayoutSavedSuccess,
            style: AppTextStyles.bodyLarge.copyWith(
              color: T.onPrimary(context),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        backgroundColor: T.primary(context),
        title: Text(
          context.l10n.vehicleSettingsTitle,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onPrimary(context),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: T.onPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicle == null
          ? _buildNoVehicleState()
          : _buildContent(),
    );
  }

  Widget _buildNoVehicleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(IconsaxPlusBold.car, size: 80, color: T.primary(context)),
            const SizedBox(height: 24),
            Text(
              context.l10n.noVehicleRegistered,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noVehicleRegisteredBody,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVehicleSummaryCard(),
            const SizedBox(height: 16),
            _buildVehicleTypeCard(),
            const SizedBox(height: 16),
            _buildSeatMapCard(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSummaryCard() {
    final vehicle = _vehicle!;
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context.l10n.vehicleDataSection),
          const SizedBox(height: 12),
          _summaryRow(context.l10n.vehicleModelLabel, vehicle.model),
          _summaryRow(
            context.l10n.vehiclePlateNumberLabel,
            vehicle.plateNumber,
          ),
          const SizedBox(height: 12),
          VehicleColorDropdown(
            value: _color,
            onChanged: (key) => setState(() => _color = key),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeCard() {
    final types = _vehicleTypes.isNotEmpty
        ? _vehicleTypes.map((t) => t.type).toList()
        : AppConstants.vehicleTypes;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context.l10n.vehicleTypePickTitle),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [for (final type in types) _buildTypeTile(type)],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTile(String type) {
    final template = _templateForType(type);
    final selected = type == _selectedVehicleType;
    final art = vehicleArtFor(type);
    final label = template != null
        ? template.localizedLabel(Localizations.localeOf(context).languageCode)
        : AppConstants.vehicleTypeLabels[type] ?? type;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedVehicleType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? T.primary(context).withValues(alpha: 0.08)
                : T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? T.primary(context) : T.outline(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: art != null
                    ? Image.asset(art.asset, fit: BoxFit.contain)
                    : Icon(
                        IconsaxPlusBold.car,
                        size: 48,
                        color: T.onSurfaceVariant(context),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: selected ? T.primary(context) : T.onSurface(context),
                ),
              ),
              if (template != null)
                Text(
                  context.l10n.seatsCount(template.seats),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatMapCard() {
    final art = _art;
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardTitle(context.l10n.seatLayoutSection),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.l10n.seatsCount(_seatCount),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            art != null
                ? context.l10n.vehicleSeatMapHint
                : context.l10n.vehicleSeatMapUnavailable,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
          if (art != null) ...[
            const SizedBox(height: 16),
            Center(
              child: ExpandableCabinView(
                art: art,
                title: context.l10n.seatLayoutSection,
                thumbnailWidth: 200,
                seatBuilder: (context, seatNumber, _) =>
                    _SeatNumber(number: seatNumber),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildMixingToggle(),
        ],
      ),
    );
  }

  Widget _cardTitle(String text) {
    return Text(
      text,
      style: AppTextStyles.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: T.onSurface(context),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: T.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixingToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: T.secondary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              color: T.secondary(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.preventGenderMixing,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: T.onSurface(context),
              ),
            ),
          ),
          Switch(
            value: _preventGenderMixing,
            activeThumbColor: T.primary(context),
            onChanged: (v) => setState(() => _preventGenderMixing = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: T.primary(context),
          foregroundColor: T.onPrimary(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                context.l10n.saveChangesVehicle,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.outline(context)),
      ),
      child: child,
    );
  }
}

/// A seat's number drawn on the artwork, matching what passengers book.
class _SeatNumber extends StatelessWidget {
  const _SeatNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: T.primary(context).withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTextStyles.labelLarge.copyWith(
              color: T.onPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
