import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/websocket_service.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/rating_service.dart';
import '../../core/theme/colors.dart';
import '../../models/booking_model.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../widgets/seat_layout_widget.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingGroupId;

  const BookingDetailsScreen({super.key, required this.bookingGroupId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingService _bookingService = BookingService();
  final WebSocketService _socketService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _trackingSubscription;

  BookingGroupModel? _group;
  TripModel? _trip;
  bool _isLoading = true;
  String? _subscribedTripId;
  GoogleMapController? _mapController;
  LatLng? _liveDriverLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final group = await _bookingService.getBookingGroupById(widget.bookingGroupId);
    if (!mounted) return;
    setState(() {
      _group = group;
      _trip = group?.trip;
      _isLoading = false;
    });
    if (group?.trip != null) {
      await _initTracking(group!.trip!.id);
      _buildMarkers();
    }
  }

  Future<void> _initTracking(String tripId) async {
    if (_subscribedTripId == tripId) return;
    _subscribedTripId = tripId;
    await _socketService.connect();
    _socketService.subscribeToTripTracking(tripId);
    _trackingSubscription?.cancel();
    _trackingSubscription = _socketService.onTrackingUpdate.listen((payload) {
      final payloadTripId = payload['tripId']?.toString();
      if (payloadTripId != tripId) return;
      final lat = payload['latitude'];
      final lng = payload['longitude'];
      if (lat is num && lng is num) {
        setState(() {
          _liveDriverLocation = LatLng(lat.toDouble(), lng.toDouble());
          _buildMarkers();
        });
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _focusMapOnDeparture();
  }

  void _buildMarkers() {
    final trip = _trip;
    if (trip == null) return;
    _markers = {
      Marker(
        markerId: const MarkerId('from'),
        position: LatLng(trip.from.latitude, trip.from.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: trip.from.name),
      ),
      if (_liveDriverLocation != null)
        Marker(
          markerId: const MarkerId('driver_live'),
          position: _liveDriverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'موقع السائق المباشر'),
        ),
    };
    _focusMapOnDeparture();
  }

  /// معاينة الخريطة: تكبير على نقطة الانطلاق فقط (وليس كامل المسار).
  void _focusMapOnDeparture() {
    final trip = _trip;
    final controller = _mapController;
    if (trip == null || controller == null) return;
    final fromLatLng = LatLng(trip.from.latitude, trip.from.longitude);
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(fromLatLng, 14),
    );
  }

  Set<int> _bookedDisplaySeats(BookingGroupModel group, TripModel trip) {
    final result = <int>{};
    for (final seatId in group.seatNumbers) {
      final coords = SeatLayoutHelpers.parseBackendSeatId(seatId);
      if (coords == null) continue;
      final display = SeatLayoutHelpers.backendCoordsToDisplayIndex(
        trip.seatLayout,
        coords.row,
        coords.col,
      );
      if (display != null) {
        result.add(display);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final group = _group;
    final trip = _trip;
    if (group == null || trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: const Center(child: Text('تعذر تحميل تفاصيل الحجز')),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');
    final userBookedSeats = _bookedDisplaySeats(group, trip);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
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
                    const Text(
                      'ملخص الحجز',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'الحالة', value: _statusText(group.status)),
                    _InfoRow(
                      label: 'عدد المقاعد',
                      value: group.seatNumbers.length.toString(),
                    ),
                    _InfoRow(
                      label: 'المقاعد',
                      value: group.seatNumbers.join(' , '),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الرحلة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'من', value: trip.from.name),
                    _InfoRow(label: 'إلى', value: trip.to.name),
                    _InfoRow(
                      label: 'التاريخ',
                      value: dateFormat.format(trip.departureTime),
                    ),
                    _InfoRow(
                      label: 'الوقت',
                      value: timeFormat.format(trip.departureTime),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الدفع',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'المدفوع للتطبيق',
                      value:
                          '${group.platformAmountTotal.toStringAsFixed(2)} ${group.currency}',
                    ),
                    _InfoRow(
                      label: 'المتبقي للسائق',
                      value:
                          '${group.driverAmountTotal.toStringAsFixed(2)} ${group.currency}',
                    ),
                    _InfoRow(
                      label: 'الإجمالي',
                      value:
                          '${group.totalAmount.toStringAsFixed(2)} ${group.currency}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تخطيط المقاعد (مقاعدك ملوّنة)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SeatLayoutWidget(
                      trip: trip,
                      highlightedSeatNumbers: userBookedSeats,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: T.outline(context)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(trip.from.latitude, trip.from.longitude),
                    zoom: 14,
                  ),
                  markers: _markers,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.tripRouteMap,
                    arguments: trip,
                  );
                },
                icon: const Icon(Icons.alt_route),
                label: const Text('عرض مسار الرحلة'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final chatService = ChatService();
                      final enabled = await chatService.checkIfChatEnabled(trip.id);
                      if (!mounted) return;
                      if (!enabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'المحادثة غير متاحة الآن. يجب على السائق تفعيل التواصل أولاً.',
                            ),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      Navigator.pushNamed(
                        context,
                        RouteNames.chat,
                        arguments: {
                          'tripId': trip.id,
                          'trip': trip,
                          'driverId': trip.driverId,
                          'driverName': trip.driverName,
                        },
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('المحادثة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!trip.isPast) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يمكنك التقييم بعد انتهاء الرحلة'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      final ratingService = RatingService();
                      final hasRated = await ratingService.hasUserRatedTrip(trip.id);
                      if (!mounted) return;
                      if (hasRated) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لقد قمت بتقييم هذه الرحلة بالفعل'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      Navigator.pushNamed(
                        context,
                        RouteNames.rating,
                        arguments: {
                          'tripId': trip.id,
                          'trip': trip,
                          'driverId': trip.driverId,
                          'driverName': trip.driverName,
                        },
                      );
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('تقييم'),
                  ),
                ),
              ],
            ),
            if (user == null) ...[
              const SizedBox(height: 8),
              const Text('يجب تسجيل الدخول لاستخدام المحادثة والتقييم'),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    if (_subscribedTripId != null) {
      _socketService.unsubscribeFromTripTracking(_subscribedTripId!);
    }
    _trackingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: T.onSurfaceVariant(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }
}
