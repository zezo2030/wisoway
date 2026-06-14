import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../utils/seat_validation.dart';
import '../../widgets/seat_layout_widget.dart';
import '../../l10n/l10n_extensions.dart';
import 'companion_picker_screen.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String tripId;

  const SeatSelectionScreen({super.key, required this.tripId});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final TripService _tripService = TripService();
  final List<int> _selectedSeats = [];

  TripModel? _trip;
  Map<String, dynamic>? _pricingPreview;
  bool _isLoading = true;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);
      Map<String, dynamic>? preview;
      if (trip != null) {
        preview = await _tripService.getTripPricingPreview(trip.id);
      }
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _pricingPreview = preview;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  void _onSeatTap(int seatNumber) {
    if (_trip == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.auth,
          messageKey: 'errorsAuthSessionExpired',
          severity: FailureSeverity.error,
          nextAction: FailureAction.reauthenticate,
          developerDetail: 'User not authenticated',
        ),
      );
      return;
    }

    if (!SeatValidation.canSelectSeat(
      trip: _trip!,
      seatNumber: seatNumber,
      userGender: userModel.gender,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.seatNotSelectable),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSeats.contains(seatNumber)) {
        _selectedSeats.remove(seatNumber);
      } else {
        _selectedSeats.add(seatNumber);
        _selectedSeats.sort();
      }
    });
  }

  Future<void> _continueToPassengerDetails() async {
    if (_trip == null || _selectedSeats.isEmpty) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'No seats selected',
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    if (user == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.auth,
          messageKey: 'errorsAuthSessionExpired',
          severity: FailureSeverity.error,
          nextAction: FailureAction.reauthenticate,
          developerDetail: 'User not authenticated',
        ),
      );
      return;
    }

    if (_trip!.driverId == user.id) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Cannot book seat on own trip',
        ),
      );
      return;
    }

    final allSelectedSeatsStillAvailable = _selectedSeats.every(
      (seatNumber) => SeatValidation.canSelectSeat(
        trip: _trip!,
        seatNumber: seatNumber,
        userGender: user.gender,
      ),
    );

    if (!allSelectedSeatsStillAvailable) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'One or more selected seats are no longer available',
        ),
      );
      await _loadTrip();
      return;
    }

    setState(() => _isBooking = true);

    final backendSeatNumbers = _selectedSeats
        .map(
          (seatNumber) => SeatLayoutHelpers.displayIndexToBackendSeatId(
            seatNumber,
            _trip!.seatLayout,
          ),
        )
        .toList();

    try {
      final booking = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompanionPickerScreen(
            trip: _trip!,
            lockedSeatNumbers: backendSeatNumbers,
            autoPick: false,
          ),
        ),
      );

      if (mounted && booking != null) {
        Navigator.pop(context, booking);
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.selectSeats)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.selectSeats)),
        body: Center(child: Text(context.l10n.tripNotFound)),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.selectSeats)),
        body: Center(child: Text(context.l10n.signInRequired)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.selectSeats)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.tripInfoTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.fromValue(_trip!.from.name)),
                    Text(context.l10n.toValue(_trip!.to.name)),
                    Text(
                      context.l10n.pricePerSeatValue(
                        '${_trip!.price}',
                        _trip!.currency,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    Text(
                      context.l10n.selectOneOrMoreSeats,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: T.primary(context),
                      ),
                    ),
                    Text(
                      context.l10n.enterPassengerDataAfterSeats,
                      style: TextStyle(
                        color: T.onSurfaceVariant(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.selectSeats,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SeatLayoutWidget(
              trip: _trip!,
              selectedSeats: _selectedSeats,
              userGender: userModel.gender,
              onSeatTap: _onSeatTap,
            ),
            const SizedBox(height: 24),
            if (_pricingPreview != null &&
                _pricingPreview!['passenger'] is Map &&
                (_pricingPreview!['passenger']
                        as Map)['requiresOnlinePayment'] ==
                    true) ...[
              Card(
                color: T.primaryContainer(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: T.primary(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.appShareWalletNotice,
                          style: TextStyle(
                            fontSize: 14,
                            color: T.onPrimaryContainer(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_selectedSeats.isNotEmpty)
              Card(
                color: AppColors.success.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.event_seat, color: AppColors.successDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.selectedSeatsValue(
                            _selectedSeats.join('، '),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: context.l10n.continueToPassengerData,
              child: Tooltip(
                message: context.l10n.continueToPassengerDataTooltip,
                child: ElevatedButton(
                  onPressed: _isBooking || _selectedSeats.isEmpty
                      ? null
                      : _continueToPassengerDetails,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : Text(
                          _selectedSeats.length == 1
                              ? context.l10n.continueBookOneSeat
                              : context.l10n.continueBookSeats(
                                  _selectedSeats.length,
                                ),
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.primaryContainer(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: T.primary(context), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.bookingRequestSentNotice,
                      style: TextStyle(
                        fontSize: 12,
                        color: T.onPrimaryContainer(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
