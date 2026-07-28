import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/booking_model.dart';
import '../../models/trip_model.dart';
import '../../models/wallet_account_model.dart';
import '../../screens/home/widgets/default_avatar.dart';

/// Post-trip summary shown after the driver marks arrival / trip completes.
/// Matches the driver "انتهت الرحلة بنجاح" design: route stats, presence roster,
/// fee breakdown, and wallet deduction / pay-now states.
class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({
    super.key,
    required this.tripId,
    this.settlement,
  });

  final String tripId;
  final Map<String, dynamic>? settlement;

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  static const Color _brand = Color(0xFF0D5C4D);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _feeRed = Color(0xFFEF4444);
  static const Color _cardBorder = Color(0xFFE8ECF0);
  static const Color _muted = Color(0xFF6B7280);

  final TripService _tripService = TripService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  TripModel? _trip;
  List<BookingModel> _bookings = const [];
  WalletAccountModel? _wallet;
  Map<String, dynamic>? _settlement;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _settlement = widget.settlement;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trip = await _tripService.getTrip(widget.tripId);
      if (trip == null) {
        throw StateError('Trip not found');
      }
      final bookings = await _bookingService.getTripBookings(widget.tripId);
      WalletAccountModel? wallet;
      try {
        wallet = await _paymentService.getWalletAccountMe();
      } catch (_) {
        wallet = null;
      }
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _bookings = bookings
            .where(
              (b) =>
                  b.status == 'completed' ||
                  b.status == 'confirmed' ||
                  b.status == 'in_progress' ||
                  b.status == 'no_show',
            )
            .toList();
        _wallet = wallet;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  double get _seatPrice => _trip?.price ?? 0;

  String get _currency => _trip?.currency ?? 'JOD';

  int get _billableSeats {
    final fromSettlement =
        (_settlement?['billableSeats'] as num?)?.toInt() ??
        _trip?.billableSeatCount;
    if (fromSettlement != null) return fromSettlement;
    return _passengerRows.where((r) => r.confirmed).fold<int>(
          0,
          (sum, r) => sum + r.seatCount,
        );
  }

  double get _serviceFee {
    final captured = _settlement?['captured'] ?? _trip?.capturedFeeAmount;
    if (captured != null) {
      final parsed = captured is num
          ? captured.toDouble()
          : double.tryParse('$captured');
      if (parsed != null) return (parsed * 100).round() / 100;
    }
    return ((_seatPrice * _billableSeats * 0.10) * 100).round() / 100;
  }

  int get _feePercent {
    final total = _seatPrice * _billableSeats;
    if (total <= 0) return 10;
    return ((_serviceFee / total) * 100).round().clamp(1, 100);
  }

  double get _passengerFaresTotal =>
      (_seatPrice * _billableSeats * 100).round() / 100;

  double get _netAmount =>
      ((_passengerFaresTotal - _serviceFee) * 100).round() / 100;

  bool get _walletNegative => (_wallet?.balance ?? 0) < 0;

  bool get _feeDeductedSuccessfully =>
      !_walletNegative &&
      ((_settlement?['captured'] != null) ||
          (_trip?.capturedFeeAmount != null) ||
          _serviceFee == 0);

  List<_PassengerRow> get _passengerRows {
    final rows = <_PassengerRow>[];
    for (final booking in _bookings) {
      final name =
          booking.userPopulated?.name ?? context.l10n.passengerFallback;
      final photo = booking.userPopulated?.photoUrl;
      if (booking.seats.isEmpty) {
        final confirmed = booking.status != 'no_show';
        rows.add(
          _PassengerRow(
            name: name,
            photoUrl: photo,
            seatCount: booking.seatCount,
            confirmed: confirmed,
            fare: confirmed ? _seatPrice * booking.seatCount : null,
          ),
        );
        continue;
      }
      for (final seat in booking.seats) {
        rows.add(
          _PassengerRow(
            name: seat.displayName.isNotEmpty ? seat.displayName : name,
            photoUrl: photo,
            seatCount: 1,
            confirmed: seat.isPresenceConfirmed,
            fare: seat.isPresenceConfirmed ? _seatPrice : null,
          ),
        );
      }
    }
    return rows;
  }

  int get _confirmedCount =>
      _passengerRows.where((r) => r.confirmed).length;

  String _money(double amount) {
    final formatted = amount.toStringAsFixed(2);
    if (_currency == 'JOD') {
      return '$formatted ${context.l10n.currencyJodShort}';
    }
    return '$formatted $_currency';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat('d MMMM yyyy', locale).format(local);
    final time = DateFormat('hh:mm a', locale).format(local);
    return '$date | $time';
  }

  String _formatClock(DateTime dt) {
    return DateFormat(
      'hh:mm a',
      Localizations.localeOf(context).toString(),
    ).format(dt.toLocal());
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) {
      return context.l10n.tripSummaryMinutesOnly(minutes);
    }
    if (minutes == 0) {
      return context.l10n.tripSummaryHoursOnly(hours);
    }
    return context.l10n.tripSummaryHoursMinutes(hours, minutes);
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.home,
      (route) => false,
    );
  }

  void _openHelp() {
    Navigator.pushNamed(context, RouteNames.support);
  }

  void _openChat() {
    final trip = _trip;
    if (trip == null) return;
    Navigator.pushNamed(
      context,
      RouteNames.groupChat,
      arguments: {'tripId': trip.id, 'trip': trip},
    );
  }

  void _payNow() {
    Navigator.pushNamed(context, RouteNames.driverWalletTopup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading || _trip == null
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: RefreshIndicator(
                      color: _brand,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildRouteCard(_trip!),
                          const SizedBox(height: 16),
                          _buildPassengersCard(),
                          const SizedBox(height: 16),
                          _buildFinanceCard(),
                          const SizedBox(height: 12),
                          _buildWalletBanner(),
                          const SizedBox(height: 16),
                          _buildChatButton(),
                          const SizedBox(height: 12),
                          _buildHomeButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.close, size: 24),
            color: const Color(0xFF111827),
          ),
          const Spacer(),
          InkWell(
            onTap: _openHelp,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  Icon(
                    IconsaxPlusLinear.message_question,
                    size: 22,
                    color: _brand,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.tripSummaryHelp,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                context.l10n.tripSummaryTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: _successGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.tripSummaryThanks,
          style: AppTextStyles.bodyMedium.copyWith(color: _muted),
        ),
      ],
    );
  }

  Widget _buildRouteCard(TripModel trip) {
    final endAt = trip.tripCompletedAt ?? DateTime.now();
    final startAt = trip.tripStartedAt ?? trip.departureTime;
    final duration = endAt.difference(startAt);
    final distance = trip.distanceKm;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 16,
                            color: _brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.tripSummaryArrivalPlace,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trip.to.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(endAt),
                        style: AppTextStyles.bodySmall.copyWith(color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipOval(
                  child: Image.asset(
                    'assets/images/trip_summary_destination.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                _statCell(
                  label: context.l10n.tripSummaryDistance,
                  icon: IconsaxPlusLinear.routing_2,
                  value: distance != null
                      ? context.l10n.distanceKmValue(
                          distance.toStringAsFixed(
                            distance >= 10 ? 0 : 1,
                          ),
                        )
                      : '—',
                ),
                _vDivider(),
                _statCell(
                  label: context.l10n.tripSummaryDuration,
                  icon: IconsaxPlusLinear.clock,
                  value: _formatDuration(duration.isNegative
                      ? Duration.zero
                      : duration),
                ),
                _vDivider(),
                _statCell(
                  label: context.l10n.tripSummaryStartTime,
                  icon: Icons.play_arrow_rounded,
                  value: _formatClock(startAt),
                ),
                _vDivider(),
                _statCell(
                  label: context.l10n.tripSummaryEndTime,
                  icon: Icons.stop_rounded,
                  value: _formatClock(endAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 56, color: _cardBorder);

  Widget _statCell({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: _muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersCard() {
    final rows = _passengerRows;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.tripSummaryConfirmedPassengers(_confirmedCount),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.l10n.tripSummaryNoPassengers,
                style: AppTextStyles.bodyMedium.copyWith(color: _muted),
              ),
            )
          else
            ...rows.map(_passengerTile),
        ],
      ),
    );
  }

  Widget _passengerTile(_PassengerRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _avatar(row.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${context.l10n.tripSummaryPassengerFare} ',
                        style: AppTextStyles.bodySmall.copyWith(color: _muted),
                      ),
                      TextSpan(
                        text: row.fare == null ? '—' : _money(row.fare!),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: row.fare == null ? _muted : _successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(row.confirmed),
        ],
      ),
    );
  }

  Widget _avatar(String? url) {
    return ClipOval(
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, __) => _avatarFallback(),
              errorWidget: (_, __, ___) => _avatarFallback(),
            )
          : _avatarFallback(),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 44,
      height: 44,
      color: _brand,
      alignment: Alignment.center,
      child: const DefaultAvatar(size: 22),
    );
  }

  Widget _statusBadge(bool confirmed) {
    final bg = confirmed ? _successGreen : const Color(0xFF9CA3AF);
    final label = confirmed
        ? context.l10n.tripSummaryConfirmed
        : context.l10n.tripSummaryNotConfirmed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? Icons.check : Icons.close,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          _financeRow(
            icon: IconsaxPlusBold.people,
            label: context.l10n.tripSummaryPassengerFares(_billableSeats),
            value: _money(_passengerFaresTotal),
            valueColor: _successGreen,
          ),
          const SizedBox(height: 14),
          _financeRow(
            icon: IconsaxPlusBold.shield_tick,
            label: context.l10n.tripSummaryTripFeePercent(_feePercent),
            value: _money(_serviceFee),
            valueColor: _feeRed,
          ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
          _financeRow(
            icon: IconsaxPlusBold.wallet_1,
            label: context.l10n.tripSummaryNetAmount,
            value: _money(_netAmount),
            valueColor: _successGreen,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _financeRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF111827),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: valueColor,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletBanner() {
    if (_walletNegative) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _feeRed.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    context.l10n.tripSummaryPaymentRequired(
                      _money(_serviceFee),
                      _money((_wallet?.balance ?? 0).abs()),
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF7F1D1D),
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _feeRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tripSummaryNegativeBalanceRestriction,
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF9F1239),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _payNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _feeRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.tripSummaryPayNow),
              ),
            ),
          ],
        ),
      );
    }

    if (!_feeDeductedSuccessfully && _serviceFee > 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripSummaryPayFeePrompt(_money(_serviceFee)),
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF9A3412),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _payNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.tripSummaryPayNow),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              context.l10n.tripSummaryFeeDeducted(_money(_serviceFee)),
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF374151),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _successGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openChat,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.tripSummaryChatTitle,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.tripSummaryChatSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(
                IconsaxPlusLinear.message_text_1,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _goHome,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          context.l10n.tripSummaryBackHome,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PassengerRow {
  const _PassengerRow({
    required this.name,
    required this.photoUrl,
    required this.seatCount,
    required this.confirmed,
    required this.fare,
  });

  final String name;
  final String? photoUrl;
  final int seatCount;
  final bool confirmed;
  final double? fare;
}

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1.5,
              color: const Color(0xFFD1D5DB),
            ),
          ),
        );
      },
    );
  }
}
