import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/services/payment_service.dart';
import '../../models/seat_layout_config.dart';
import '../../models/vehicle_type_template.dart';
import '../../models/vehicle_model.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';
import '../../l10n/l10n_extensions.dart';
import 'create_trip/create_trip_stepper.dart';
import 'create_trip/create_trip_wizard_state.dart';
import 'create_trip/step1_route.dart';
import 'create_trip/step2_details.dart';
import 'create_trip/step3_review.dart';

/// Shell for the 3-step create-trip wizard: driver-approval gate, vehicle
/// loading, step navigation and the publish call. Step content lives in
/// `create_trip/step{1,2,3}_*.dart` and shares [CreateTripWizardState].
class CreateTripScreen extends StatefulWidget {
  final VehicleService? vehicleService;

  const CreateTripScreen({super.key, this.vehicleService});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen>
    with SingleTickerProviderStateMixin {
  static const String _currency = 'JOD';

  final _formKey = GlobalKey<FormState>();
  final CreateTripWizardState _wizard = CreateTripWizardState();

  VehicleModel? _vehicle;
  List<VehicleTypeTemplate> _vehicleTypes = const [];
  bool _isLoadingVehicle = true;
  bool _isLoading = false;
  bool _isCheckingDriverApproval = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDriverApprovalGate();
    });
    _loadVehicleInfo();
  }

  @override
  void dispose() {
    _wizard.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _refreshDriverApprovalGate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userModel == null) {
      if (mounted) setState(() => _isCheckingDriverApproval = false);
      return;
    }

    setState(() => _isCheckingDriverApproval = true);
    await authProvider.loadUserProfile(silent: true);
    if (mounted) setState(() => _isCheckingDriverApproval = false);
  }

  Future<bool> _ensureCanCreateTrip() async {
    // Do not toggle _isCheckingDriverApproval here: that replaces the Form with a
    // loading scaffold, detaches _formKey, and makes currentState null before the
    // next frame — which crashes _createTrip on currentState!.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadUserProfile(silent: true);
    if (!mounted) return false;

    final user = authProvider.userModel;
    return user != null && user.canCreateTrips;
  }

  Future<void> _loadVehicleInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user != null) {
      try {
        final service = widget.vehicleService ?? VehicleService();
        final vehicleInfo = await service.getMyVehicle();
        var vehicleTypes = <VehicleTypeTemplate>[];
        try {
          vehicleTypes = await service.getVehicleTypes();
        } catch (_) {
          vehicleTypes = await service.getCachedVehicleTypes();
        }
        if (mounted) {
          setState(() {
            _vehicle = vehicleInfo;
            _vehicleTypes = vehicleTypes;
            _isLoadingVehicle = false;
            _wizard.initFromVehicle(
              vehicleInfo,
              _templateLayoutFor(vehicleInfo?.vehicleType),
            );
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingVehicle = false);
        }
      }
    } else if (mounted) {
      setState(() => _isLoadingVehicle = false);
    }
  }

  SeatLayoutConfig? _templateLayoutFor(String? vehicleType) {
    if (vehicleType == null || vehicleType.isEmpty) return null;
    for (final template in _vehicleTypes) {
      if (template.type == vehicleType) return template.layout;
    }
    return null;
  }

  // --- step navigation -----------------------------------------------------

  void _onWizardChanged() => setState(() {});

  void _goToStep(int index) {
    if (index == _wizard.stepIndex) return;
    FocusScope.of(context).unfocus();
    setState(() => _wizard.goToStep(index));
  }

  void _goNext() {
    if (_wizard.stepIndex == 0 && !_wizard.canGoStep2) return;
    if (_wizard.stepIndex == 1 && !_wizard.canGoStep3) return;
    _goToStep(_wizard.stepIndex + 1);
  }

  Future<void> _openVehicleSettings() async {
    await Navigator.pushNamed(context, RouteNames.vehicleSettings);
    await _loadVehicleInfo();
  }

  // --- date / time ---------------------------------------------------------

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: T.primary(context),
          onPrimary: T.onPrimary(context),
          onSurface: T.onSurface(context).withValues(alpha: 0.87),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _selectDepartureDate() async {
    final current = _wizard.departureTime;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _pickerTheme,
    );
    if (picked == null || !mounted) return;

    final fallback = TimeOfDay.now();
    setState(() {
      _wizard.departureTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current?.hour ?? fallback.hour,
        current?.minute ?? fallback.minute,
      );
    });
  }

  Future<void> _selectDepartureTimeOfDay() async {
    final current = _wizard.departureTime;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay.fromDateTime(current)
          : TimeOfDay.now(),
      builder: _pickerTheme,
    );
    if (time == null || !mounted) return;

    final base = current ?? DateTime.now().add(const Duration(days: 1));
    setState(() {
      _wizard.departureTime = DateTime(
        base.year,
        base.month,
        base.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectRecurrenceUntil() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (_wizard.recurrenceUntil ?? DateTime.now()).add(
        const Duration(days: 30),
      ),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.l10n.recurrenceUntilHelp,
      builder: _pickerTheme,
    );
    if (picked != null && mounted) {
      setState(() => _wizard.recurrenceUntil = picked);
    }
  }

  // --- publish -------------------------------------------------------------

  Future<void> _createTrip() async {
    if (!await _ensureCanCreateTrip()) return;
    if (!mounted) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    if (_wizard.from == null ||
        _wizard.to == null ||
        _wizard.departureTime == null) {
      _showError(context.l10n.completeLocationAndTimeData);
      return;
    }
    if (_wizard.departureTime!.isBefore(DateTime.now())) {
      _showError(context.l10n.departureTimeMustBeFuture);
      return;
    }
    final price = _wizard.price;
    if (price == null) {
      _showError(context.l10n.enterValidNumber);
      return;
    }
    if (!_wizard.hasLayout || _wizard.availableSeatCount < 1) {
      _showError(context.l10n.noSeatLayoutSet);
      return;
    }

    try {
      final wallet = await PaymentService().getWalletAccountMe();
      if (!mounted) return;
      if (wallet.balance < 0) {
        ErrorSurface.showFailure(
          context,
          Failure(
            category: FailureCategory.permission,
            messageKey: 'errorsNegativeWalletBalance',
            displayMessage: context.l10n.negativeWalletBalanceBlocked,
            severity: FailureSeverity.error,
            nextAction: FailureAction.topUpWallet,
            developerDetail: 'wallet.balance=${wallet.balance}',
          ),
        );
        return;
      }
    } catch (_) {
      // Backend still enforces this; continue if wallet lookup fails.
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final user = authProvider.userModel;

      if (user == null) throw Exception('المستخدم غير مسجل دخول');

      final tripId = await tripProvider.createTrip(
        from: _wizard.from!,
        to: _wizard.to!,
        departureTime: _wizard.departureTime!,
        price: price,
        currency: _currency,
        stops: _wizard.stops.isNotEmpty ? List.of(_wizard.stops) : null,
        notes: _wizard.notes.isNotEmpty ? _wizard.notes : null,
        recurrence: _wizard.buildRecurrencePayload(),
        availableSeats: _wizard.availableSeatCount,
        preventGenderMixing: _wizard.preventGenderMixing,
      );

      if (tripId != null && mounted) {
        _showSuccess(context.l10n.tripCreatedSuccess);
        Navigator.pop(context, tripId);
      } else {
        throw Exception('فشل إنشاء الرحلة');
      }
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.error(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.error_outline, color: T.onError(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.onError(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.success(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: T.onPrimary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.onPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    // Only gate on the initial approval check. Listening to isRefreshingProfile
    // unmounted the Form on every profile refresh (including create-trip submit)
    // and left _formKey.currentState null.
    if (_isCheckingDriverApproval) {
      return Scaffold(
        backgroundColor: T.background(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: T.primary(context)),
              const SizedBox(height: 16),
              Text(
                context.l10n.loading,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (user != null && !user.canCreateTrips) {
      return _buildUnderReviewScaffold(context);
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        backgroundColor: T.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.createNewTripTitle,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: T.onSurface(context)),
          tooltip: context.l10n.backLabel,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: T.onSurface(context)),
            tooltip: context.l10n.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: T.outline(context)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            CreateTripStepper(
              currentStep: _wizard.stepIndex,
              onStepTapped: _goToStep,
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _maxContentWidth(context),
                    ),
                    child: Form(
                      key: _formKey,
                      child: IndexedStack(
                        index: _wizard.stepIndex,
                        sizing: StackFit.expand,
                        children: [
                          Step1Route(
                            wizard: _wizard,
                            onChanged: _onWizardChanged,
                          ),
                          Step2Details(
                            wizard: _wizard,
                            isLoadingVehicle: _isLoadingVehicle,
                            onChanged: _onWizardChanged,
                            onPickDate: _selectDepartureDate,
                            onPickTime: _selectDepartureTimeOfDay,
                            onPickRecurrenceUntil: _selectRecurrenceUntil,
                            onOpenVehicleSettings: _openVehicleSettings,
                          ),
                          Step3Review(
                            wizard: _wizard,
                            vehicle: _vehicle,
                            currency: _currency,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  double _maxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 600;
    if (width >= 900) return 500;
    return double.infinity;
  }

  Widget _buildUnderReviewScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: T.background(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(IconsaxPlusBold.timer, size: 80, color: T.primary(context)),
              const SizedBox(height: 24),
              Text(
                context.l10n.driverAccountUnderReview,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context).withValues(alpha: 0.87),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.driverAccountUnderReviewBody,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 15,
                  color: T.onSurface(context).withValues(alpha: 0.54),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  context.l10n.backToHome,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.primary(context),
                  foregroundColor: T.onPrimary(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- footer --------------------------------------------------------------

  Widget _buildFooter(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final forwardIcon = isRtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;
    final backIcon = isRtl
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;

    final step = _wizard.stepIndex;
    final isReview = step == CreateTripWizardState.lastStepIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        border: Border(top: BorderSide(color: T.outline(context))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxContentWidth(context)),
          child: Row(
            children: [
              if (step > 0) ...[
                Expanded(
                  child: _secondaryButton(
                    label: isReview
                        ? context.l10n.backToEdit
                        : context.l10n.back,
                    icon: backIcon,
                    onPressed: _isLoading
                        ? null
                        : () => _goToStep(isReview ? 1 : step - 1),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: isReview
                    ? _primaryButton(
                        label: context.l10n.publishTrip,
                        icon: IconsaxPlusBroken.send_2,
                        onPressed: _isLoading || !_wizard.canPublish
                            ? null
                            : _createTrip,
                        busy: _isLoading,
                      )
                    : _primaryButton(
                        label: context.l10n.next,
                        icon: forwardIcon,
                        onPressed: _canGoNext ? _goNext : null,
                        busy: false,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canGoNext {
    if (_isLoading) return false;
    if (_wizard.stepIndex == 0) return _wizard.canGoStep2;
    if (_wizard.stepIndex == 1) return _wizard.canGoStep3;
    return false;
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool busy,
  }) {
    return SizedBox(
      height: 54,
      child: Semantics(
        button: true,
        label: label,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(icon, size: 20),
          label: Text(
            label,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: T.primary(context),
            foregroundColor: T.onPrimary(context),
            disabledBackgroundColor: T.primary(
              context,
            ).withValues(alpha: 0.35),
            disabledForegroundColor: T.onPrimary(
              context,
            ).withValues(alpha: 0.8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: Semantics(
        button: true,
        label: label,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: T.primary(context)),
          label: Text(
            label,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: T.primary(context),
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: T.primary(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
