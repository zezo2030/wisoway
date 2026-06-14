import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/error_surface.dart';
import '../../widgets/notification_icon_button.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/empty_state.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../l10n/l10n_extensions.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'active';

  Future<void> _refreshTrips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user == null) return;

    await Provider.of<TripProvider>(
      context,
      listen: false,
    ).fetchDriverTrips(driverId: user.id, status: _selectedStatus);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = 'active';
            break;
          case 1:
            _selectedStatus = 'hidden';
            break;
          case 2:
            _selectedStatus = 'completed';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final userModel = authProvider.userModel;

    if (user == null || userModel == null || !userModel.canCreateTrips) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.myTripsTitleLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userModel != null &&
                      userModel.isDriver &&
                      !userModel.isDriverApproved
                  ? context.l10n.driverAccountUnderReviewTrips
                  : context.l10n.mustBeApprovedDriver,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.myTripsTitleLabel,
          style: TextStyle(
            color: T.onSurface(context),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(iconColor: T.onSurface(context)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: T.primary(context),
          unselectedLabelColor: T.onSurfaceVariant(context),
          indicatorColor: T.primary(context),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: context.l10n.tabActive),
            Tab(text: context.l10n.tabHidden),
            Tab(text: context.l10n.tabCompleted),
          ],
        ),
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: Provider.of<TripProvider>(
          context,
          listen: false,
        ).getDriverTripsStream(user.id, status: _selectedStatus),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(context.l10n.errorWithDetail('${snapshot.error}')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text(context.l10n.retryLabel),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshTrips,
              color: T.primary(context),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: EmptyState(
                    icon: _selectedStatus == 'active'
                        ? Icons.directions_car_outlined
                        : _selectedStatus == 'hidden'
                        ? Icons.visibility_off_outlined
                        : Icons.check_circle_outline,
                    title: _selectedStatus == 'active'
                        ? context.l10n.noActiveTrips
                        : _selectedStatus == 'hidden'
                        ? context.l10n.noHiddenTrips
                        : context.l10n.noCompletedTrips,
                    showCircleBackground: false,
                    iconSize: 64,
                    action: _selectedStatus == 'active'
                        ? ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteNames.createTrip,
                              );
                            },
                            icon: const Icon(IconsaxPlusBold.add_circle),
                            label: Text(context.l10n.createTripShort),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: T.primary(context),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTrips,
            color: T.primary(context),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _TripCard(trip: trip, onPaid: _refreshTrips);
              },
            ),
          );
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: context.l10n.createNewTripSemantic,
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, RouteNames.createTrip);
          },
          tooltip: context.l10n.newTrip,
          backgroundColor: T.primary(context),
          icon: const Icon(IconsaxPlusBold.add, color: AppColors.white),
          label: Text(
            context.l10n.newTrip,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final TripModel trip;
  final Future<void> Function() onPaid;

  const _TripCard({required this.trip, required this.onPaid});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  final PaymentService _paymentService = PaymentService();
  bool _isPaying = false;

  TripModel get trip => widget.trip;

  double get _tripFeeAmount =>
      ((trip.price * trip.totalSeats * 0.05) * 100).round() / 100;

  Future<void> _showFeeInvoice() async {
    final amount = _tripFeeAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tripFeeInvoiceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _invoiceRow(
              context.l10n.seatPrice,
              '${trip.price} ${trip.currency}',
            ),
            _invoiceRow(context.l10n.seatsCountLabel, '${trip.totalSeats}'),
            _invoiceRow(context.l10n.feePercentage, '5%'),
            const Divider(height: 24),
            _invoiceRow(
              context.l10n.totalLabel,
              '${amount.toStringAsFixed(2)} ${trip.currency}',
              isTotal: true,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.tripFeeDeductExplanation,
              style: TextStyle(
                color: T.onSurfaceVariant(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.payFees),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _payTripFee();
    }
  }

  Widget _invoiceRow(String label, String value, {bool isTotal = false}) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
      fontSize: isTotal ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> _payTripFee() async {
    setState(() => _isPaying = true);
    try {
      await _paymentService.chargeDriverTrip(
        tripId: trip.id,
        idempotencyKey:
            'driver-trip-fee:${trip.id}:${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tripFeePaidSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      await widget.onPaid();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    Color getStatusColor() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return AppColors.success;
        case 'fully_booked':
        case 'hidden':
          return AppColors.warning;
        case 'in_progress':
        case 'completed':
          return AppColors.info;
        case 'cancelled':
          return T.error(context);
        case 'draft':
        default:
          return T.onSurfaceVariant(context);
      }
    }

    String getStatusLabel() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return context.l10n.statusActive;
        case 'draft':
          return context.l10n.statusDraft;
        case 'fully_booked':
          return context.l10n.statusFullyBooked;
        case 'in_progress':
          return context.l10n.statusInProgress;
        case 'hidden':
          return context.l10n.statusHidden;
        case 'completed':
          return context.l10n.statusCompleted;
        case 'cancelled':
          return context.l10n.statusCancelled;
        default:
          return context.l10n.statusUnknown;
      }
    }

    IconData getStatusIcon() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return Icons.circle;
        case 'hidden':
          return Icons.visibility_off;
        case 'cancelled':
          return Icons.cancel;
        case 'in_progress':
          return Icons.directions_car;
        default:
          return Icons.check_circle;
      }
    }

    final statusColor = getStatusColor();

    final String fromName = trip.from.name.isNotEmpty
        ? trip.from.name
        : (trip.from.address ?? context.l10n.unknownLocation);
    final String toName = trip.to.name.isNotEmpty
        ? trip.to.name
        : (trip.to.address ?? context.l10n.unknownLocation);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Semantics(
          button: true,
          label: context.l10n.tripFromToSemantic(
            trip.from.name,
            trip.to.name,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.tripManagement,
                arguments: trip.id,
              );
            },
            splashColor: statusColor.withOpacity(0.08),
            highlightColor: statusColor.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- HEADER: Status & Time ----------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              getStatusLabel(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Date & Time
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusLinear.clock,
                            color: T.onSurfaceVariant(context),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${dateFormat.format(trip.departureTime)}  ${timeFormat.format(trip.departureTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: T.onSurfaceVariant(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ---------------- ROUTE: Vertical ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dots & line
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: T.primary(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 28,
                            color: T.primary(context).withOpacity(0.25),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // From & To labels
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FROM
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.fromShort,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: T.onSurfaceVariant(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  fromName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: T.onSurface(context),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // TO
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.toShort,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: T.onSurfaceVariant(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  toName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: T.onSurface(context),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ---------------- FOOTER: Price & Seats ----------------
                Container(
                  decoration: BoxDecoration(
                    color: T.surfaceVariant(context).withOpacity(0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      // Price
                      Icon(
                        IconsaxPlusBold.wallet_1,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${trip.price} ${trip.currency}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.perSeatSuffix,
                        style: TextStyle(
                          fontSize: 12,
                          color: T.onSurfaceVariant(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Seats
                      Icon(
                        IconsaxPlusBold.people,
                        color: T.primary(context),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${trip.availableSeats}/${trip.totalSeats}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: T.primary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.seatsWord,
                        style: TextStyle(
                          fontSize: 12,
                          color: T.onSurfaceVariant(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                if (trip.communicationFeeStatus != 'paid')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isPaying ? null : _showFeeInvoice,
                        icon: _isPaying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(IconsaxPlusBold.receipt_2),
                        label: Text(
                          _isPaying
                              ? context.l10n.payingInProgress
                              : context.l10n.payFees,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (trip.communicationFeeStatus == 'paid')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          IconsaxPlusBold.tick_circle,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.tripFeePaidLabel,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
