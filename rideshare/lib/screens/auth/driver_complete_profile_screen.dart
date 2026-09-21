import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/errors/failure.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/vehicle_type_template.dart';
import '../../widgets/auth/auth_hero.dart';
import '../../widgets/auth/auth_step_indicator.dart';
import 'driver_complete/driver_complete_step2.dart';
import 'driver_complete/driver_complete_step3.dart';
import 'driver_complete/driver_profile_wizard_state.dart';

/// The step 2/3 illustration frames the driver in its upper half, so the ribbon
/// is cropped above centre to keep his face and the wheel clear of the sheet.
const Alignment _heroArtFocus = Alignment(0, -0.5);

/// Shell for driver wizard steps 2 and 3.
///
/// Two entry points:
/// * new registration — arrives with a pending registration token, submits
///   `POST /auth/driver/register` at the end of step 3;
/// * pending edit (`{'editMode': true}`) — prefills from the account + vehicle
///   and submits `PATCH /auth/driver/registration` instead.
class DriverCompleteProfileScreen extends StatefulWidget {
  const DriverCompleteProfileScreen({super.key});

  @override
  State<DriverCompleteProfileScreen> createState() =>
      _DriverCompleteProfileScreenState();
}

class _DriverCompleteProfileScreenState
    extends State<DriverCompleteProfileScreen> {
  final _step2FormKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final VehicleService _vehicleService = VehicleService();

  late final DriverProfileWizardState _state = DriverProfileWizardState();

  /// Seat counts come from the backend catalog; the local map keeps the
  /// auto-fill working on the very first run without network.
  Map<String, VehicleTypeTemplate> _templatesByType = {};

  /// Mirrors VEHICLE_TYPE_CATALOG in
  /// `rideshare-backend/src/modules/vehicles/vehicle-types.ts` — passenger
  /// seats only, the driver's seat is never bookable.
  static const Map<String, int> _fallbackSeatsByType = {
    AppConstants.vehicleTypeStandardCar: 4,
    AppConstants.vehicleTypeFamilySuv: 6,
    AppConstants.vehicleTypeMediumBus: 10,
    AppConstants.vehicleTypeLargeBus: 22,
  };

  bool _isEditMode = false;
  bool _isBootstrapping = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleTemplates();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleTemplates() async {
    try {
      final templates = await _vehicleService.getVehicleTypes();
      if (!mounted) return;
      setState(() {
        _templatesByType = {for (final t in templates) t.type: t};
      });
      final seats = _seatsForType(_state.vehicleType);
      if (seats != null) _state.seatsController.text = '$seats';
    } catch (_) {
      // Offline first run — the fallback seat counts still auto-fill.
    }
  }

  int? _seatsForType(String? type) {
    if (type == null) return null;
    return _templatesByType[type]?.seats ?? _fallbackSeatsByType[type];
  }

  /// Decides between "create account" and "edit while pending", and prefills
  /// the wizard from the existing account when editing.
  Future<void> _bootstrap() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;

    final requestedEdit = args?['editMode'] == true;
    final pendingDriverAccount =
        user != null &&
        user.role == AppConstants.roleDriver &&
        !user.isDriverApproved;

    _isEditMode = requestedEdit || (pendingDriverAccount && !requestedEdit);

    if (_isEditMode && user != null) {
      _state.existingPhotoUrl = user.photoUrl;
      try {
        final vehicle = await _vehicleService.getMyVehicle();
        if (vehicle != null) {
          _state.plateController.text = vehicle.plateNumber;
          _state.modelController.text = vehicle.model;
          _state.setVehicleType(
            vehicle.vehicleType,
            label:
                AppConstants.vehicleTypeLabels[vehicle.vehicleType] ??
                vehicle.vehicleType,
            // The catalog wins over the stored count so an updated template
            // corrects an old vehicle row instead of carrying it forward.
            seats: _seatsForType(vehicle.vehicleType) ?? vehicle.seats,
          );
          _state.existingLicenseUrl = vehicle.licenseImageUrl;
          _state.existingVehicleLicenseUrl = vehicle.vehicleLicenseImageUrl;
          _state.existingInsuranceUrl = vehicle.insuranceImageUrl;
          _state.existingCarUrl = vehicle.carImageUrl;
        }
      } catch (_) {
        // A missing vehicle just means nothing to prefill.
      }
    }

    if (mounted) setState(() => _isBootstrapping = false);
  }

  // ── Pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickFile(void Function(File file) assign) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconsaxPlusLinear.gallery),
              title: Text(context.l10n.fromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.camera),
              title: Text(context.l10n.fromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _storageService.pickImage(source: source);
    if (picked == null || !mounted) return;
    _state.setFile((_) => assign(File(picked.path)));
  }

  Future<void> _selectVehicleType() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in AppConstants.vehicleTypes)
              ListTile(
                title: Text(AppConstants.vehicleTypeLabels[type] ?? type),
                trailing: _state.vehicleType == type
                    ? Icon(
                        IconsaxPlusBold.tick_circle,
                        color: T.primary(sheetContext),
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, type),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    _state.setVehicleType(
      selected,
      label: AppConstants.vehicleTypeLabels[selected] ?? selected,
      seats: _seatsForType(selected),
    );
  }

  // ── Navigation between steps ────────────────────────────────────────────

  void _continueToStep3() {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;
    if (!_state.hasProfilePhoto) {
      _showValidation('Personal photo not uploaded');
      return;
    }
    if (!_state.hasLicense) {
      _showValidation('Driver license photo not uploaded');
      return;
    }
    // Seats are derived, not typed, so the form can't guard them: an empty
    // value means the picked type is missing from the catalog.
    final seats = int.tryParse(_state.seatsController.text.trim());
    if (seats == null || seats < 1) {
      _showValidation('No seat count for vehicle type ${_state.vehicleType}');
      return;
    }
    _state.goToStep(3);
  }

  void _showValidation(String developerDetail) {
    ErrorSurface.showFailure(
      context,
      Failure(
        category: FailureCategory.validation,
        messageKey: 'errorsValidationGeneric',
        severity: FailureSeverity.warning,
        developerDetail: developerDetail,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_state.hasVehicleLicense) {
      _showValidation('Vehicle license photo not uploaded');
      return;
    }
    if (!_state.hasInsurance) {
      _showSnackBar(context.l10n.insuranceImageRequired, T.error(context));
      return;
    }
    if (!_state.hasCarPhoto) {
      _showValidation('Car photo not uploaded');
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();

    try {
      if (_isEditMode) {
        await authProvider.updatePendingDriverRegistration(
          profileImage: _state.profileImage,
          vehicleType: _state.vehicleType,
          plateNumber: _state.plateController.text.trim(),
          model: _state.modelController.text.trim(),
          seats: int.tryParse(_state.seatsController.text.trim()),
          driverLicenseImage: _state.licenseImage,
          vehicleLicenseImage: _state.vehicleLicenseImage,
          insuranceImage: _state.insuranceImage,
          carImage: _state.carImage,
        );

        if (!mounted) return;
        _showSnackBar(
          context.l10n.registrationUpdatedSuccess,
          AppColors.success,
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.driverPendingApproval,
          (route) => false,
        );
        return;
      }

      await authProvider.registerDriver(
        profileImage: _state.profileImage!,
        vehicleType: _state.vehicleType!,
        plateNumber: _state.plateController.text.trim(),
        model: _state.modelController.text.trim(),
        seats: int.parse(_state.seatsController.text.trim()),
        driverLicenseImage: _state.licenseImage!,
        vehicleLicenseImage: _state.vehicleLicenseImage!,
        insuranceImage: _state.insuranceImage!,
        carImage: _state.carImage!,
      );

      if (!mounted) return;
      _showSnackBar(context.l10n.driverProfileSubmitted, AppColors.success);
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.driverPendingApproval,
        (route) => false,
      );
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return Scaffold(
        backgroundColor: T.primary(context),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(T.onPrimary(context)),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final step = _state.step;
        final l10n = context.l10n;

        return PopScope(
          canPop: step == 2,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && step == 3) _state.goToStep(2);
          },
          child: Scaffold(
            backgroundColor: AuthHero.backdrop,
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopBar(step),
                  AuthHeroTitle(
                    icon: IconsaxPlusBold.personalcard,
                    title: l10n.completeDriverProfileTitle,
                    subtitle: step == 2
                        ? l10n.driverStep2Badge
                        : l10n.driverStep3Badge,
                  ),
                  AuthHeroSheet(
                    art: const AuthHeroArt(
                      asset:
                          'assets/illustrations/auth/auth_driver_step2_header.webp',
                      focus: _heroArtFocus,
                      dark: true,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The captions need a solid surface to be readable;
                          // over the illustration they were unusable.
                          AuthStepIndicator(
                            currentStep: step,
                            totalSteps: 3,
                            labels: [
                              l10n.authStepperBasicInfo,
                              l10n.authStepperIdDocs,
                              l10n.authStepperVehicleInfo,
                            ],
                          ),
                          const SizedBox(height: 22),
                          step == 2
                              ? DriverCompleteStep2(
                                  state: _state,
                                  formKey: _step2FormKey,
                                  onPickProfilePhoto: () =>
                                      _pickFile((f) => _state.profileImage = f),
                                  onPickLicense: () =>
                                      _pickFile((f) => _state.licenseImage = f),
                                  onSelectVehicleType: _selectVehicleType,
                                  onContinue: _continueToStep3,
                                )
                              : DriverCompleteStep3(
                                  state: _state,
                                  onPickVehicleLicense: () => _pickFile(
                                    (f) => _state.vehicleLicenseImage = f,
                                  ),
                                  onPickInsurance: () => _pickFile(
                                    (f) => _state.insuranceImage = f,
                                  ),
                                  onPickCarPhoto: () =>
                                      _pickFile((f) => _state.carImage = f),
                                  onBack: () => _state.goToStep(2),
                                  onSubmit: _submit,
                                  isSubmitting: _isSubmitting,
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Back chevron and the help affordance, on the hero's flat band.
  Widget _buildTopBar(int step) {
    return ColoredBox(
      color: AuthHero.backdrop,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: AuthHero.ink,
                ),
                onPressed: () {
                  if (step == 3) {
                    _state.goToStep(2);
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AuthHero.chipFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuthHero.chipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconsaxPlusLinear.message_question,
                      size: 16,
                      color: T.primary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.authNeedHelp,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: T.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
