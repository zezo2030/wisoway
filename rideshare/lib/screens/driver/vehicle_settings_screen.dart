import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../models/seat_layout_config.dart';
import '../../models/vehicle_model.dart';

class VehicleSettingsScreen extends StatefulWidget {
  const VehicleSettingsScreen({super.key});

  @override
  State<VehicleSettingsScreen> createState() => _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState extends State<VehicleSettingsScreen> {
  final VehicleService _vehicleService = VehicleService();

  VehicleModel? _vehicle;
  bool _isLoading = true;
  bool _isSaving = false;

  // Seat layout state
  int _rows = 2;
  int _seatsPerRow = 2;
  bool _isCustomLayout = false;
  List<int> _customRowConfigs = [1, 3];
  bool _preventGenderMixing = true;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final vehicle = await _vehicleService.getMyVehicle();
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        if (vehicle?.seatLayout != null) {
          final layout = vehicle!.seatLayout!;
          _rows = layout.rows;
          _seatsPerRow = layout.seatsPerRow;
          _preventGenderMixing = layout.preventGenderMixing;
          if (layout.seatsPerRowList != null &&
              layout.seatsPerRowList!.isNotEmpty) {
            _isCustomLayout = true;
            _customRowConfigs = List<int>.from(layout.seatsPerRowList!);
          }
        } else if (vehicle != null) {
          // Default suggestion based on the vehicle's total seat count.
          final total = vehicle.seats.clamp(1, 50);
          _seatsPerRow = (total / 2).ceil().clamp(1, 10);
          _rows = (total / _seatsPerRow).ceil().clamp(1, 10);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  Future<void> _save() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;

    final layout = SeatLayoutConfig(
      rows: _rows,
      seatsPerRow: _seatsPerRow,
      seatsPerRowList: _isCustomLayout ? _customRowConfigs : null,
      preventGenderMixing: _preventGenderMixing,
    );

    setState(() => _isSaving = true);
    try {
      final updated = await _vehicleService.updateVehicle(
        vehicle.id,
        seatLayout: layout,
      );
      if (!mounted) return;
      setState(() => _vehicle = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: T.success(context),
          content: Text(
            'تم حفظ تخطيط مقاعد السيارة',
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
          'إعدادات السيارة',
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
              'لم يتم تسجيل سيارة بعد',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تحتاج إلى تسجيل سيارتك من خلال إكمال ملف السائق قبل تخصيص تخطيط المقاعد.',
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
            _buildSeatLayoutCard(),
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
          Text(
            'بيانات السيارة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('الموديل', vehicle.model),
          _summaryRow('النوع', vehicle.vehicleType),
          _summaryRow('رقم اللوحة', vehicle.plateNumber),
          _summaryRow('عدد المقاعد المسجل', '${vehicle.seats}'),
        ],
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

  Widget _buildSeatLayoutCard() {
    final totalSeats = _isCustomLayout
        ? _customRowConfigs.fold<int>(0, (sum, item) => sum + item)
        : _rows * _seatsPerRow;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تخطيط المقاعد',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
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
                  '$totalSeats مقعد',
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
            'هذا التخطيط يُستخدم لكل الرحلات التي تنشئها بهذه السيارة.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: T.surfaceVariant(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeToggle(
                    title: 'نظام الشبكة',
                    isActive: !_isCustomLayout,
                    onTap: () => setState(() => _isCustomLayout = false),
                  ),
                ),
                Expanded(
                  child: _buildModeToggle(
                    title: 'توزيع مخصص',
                    isActive: _isCustomLayout,
                    onTap: () => setState(() => _isCustomLayout = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_isCustomLayout)
            Row(
              children: [
                Expanded(
                  child: _buildCounter(
                    label: 'الصفوف',
                    value: _rows,
                    icon: IconsaxPlusBroken.row_vertical,
                    onDecrease: _rows > 1
                        ? () => setState(() => _rows--)
                        : null,
                    onIncrease: _rows < 10
                        ? () => setState(() => _rows++)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCounter(
                    label: 'بكل صف',
                    value: _seatsPerRow,
                    icon: Icons.airline_seat_recline_normal_rounded,
                    onDecrease: _seatsPerRow > 1
                        ? () => setState(() => _seatsPerRow--)
                        : null,
                    onIncrease: _seatsPerRow < 10
                        ? () => setState(() => _seatsPerRow++)
                        : null,
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'حدد عدد المقاعد في كل صف:',
              style: AppTextStyles.labelLarge.copyWith(
                color: T.onSurface(context).withValues(alpha: 0.54),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_customRowConfigs.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: T.primary(context).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.primary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCounter(
                        label: index == 0
                            ? 'بجانب السائق'
                            : 'الصف ${index + 1}',
                        value: _customRowConfigs[index],
                        icon: Icons.airline_seat_recline_normal_rounded,
                        onDecrease: _customRowConfigs[index] > 1
                            ? () => setState(() => _customRowConfigs[index]--)
                            : null,
                        onIncrease: _customRowConfigs[index] < 4
                            ? () => setState(() => _customRowConfigs[index]++)
                            : null,
                      ),
                    ),
                    if (_customRowConfigs.length > 1)
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: T.error(context),
                        ),
                        onPressed: () =>
                            setState(() => _customRowConfigs.removeAt(index)),
                      ),
                  ],
                ),
              );
            }),
            if (_customRowConfigs.length < 10)
              TextButton.icon(
                onPressed: () => setState(() => _customRowConfigs.add(3)),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: T.primary(context),
                ),
                label: Text(
                  'إضافة صف جديد',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: T.primary(context),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          _buildMixingToggle(),
        ],
      ),
    );
  }

  Widget _buildModeToggle({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? T.primary(context) : T.primary(context).withValues(alpha: 0.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? T.onPrimary(context)
                  : T.onSurfaceVariant(context),
            ),
          ),
        ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Text(
                'منع الاختلاط',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
          Switch(
            value: _preventGenderMixing,
            activeThumbColor: T.primary(context).withValues(alpha: 0.3),
            onChanged: (v) => setState(() => _preventGenderMixing = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required IconData icon,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: T.primary(context), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontSize: 13,
                    color: T.onSurface(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onDecrease,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: onDecrease == null
                        ? T.surfaceVariant(context)
                        : T.surface(context),
                    border: Border.all(color: T.outlineVariant(context)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 18,
                    color: onDecrease == null
                        ? T.textDisabled(context)
                        : T.onSurface(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$value',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onIncrease,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: onIncrease == null
                        ? T.surfaceVariant(context)
                        : T.surface(context),
                    border: Border.all(color: T.outlineVariant(context)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: onIncrease == null
                        ? T.textDisabled(context)
                        : T.onSurface(context),
                  ),
                ),
              ),
            ],
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
                'حفظ التغييرات',
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
