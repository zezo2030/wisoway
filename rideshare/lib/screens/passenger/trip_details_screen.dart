import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/booking_model.dart';
import '../../models/trip_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/rating_service.dart';
import '../../core/api/websocket_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../utils/booking_seat_formatter.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../widgets/seat_layout_widget.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final BookingModel? initialBooking;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    this.initialBooking,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripModel? _trip;
  BookingModel? _activeBooking;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  final WebSocketService _socketService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _trackingSubscription;
  LatLng? _liveDriverLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _activeBooking = _isActiveTripBooking(widget.initialBooking)
        ? widget.initialBooking
        : null;
    _loadTrip();
    _initTracking();
  }

  Future<void> _initTracking() async {
    await _socketService.connect();
    _socketService.subscribeToTripTracking(widget.tripId);
    _trackingSubscription = _socketService.onTrackingUpdate.listen((payload) {
      final payloadTripId = payload['tripId']?.toString();
      if (payloadTripId != widget.tripId) {
        return;
      }
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

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);
      final activeBooking = _activeBooking ?? await _loadActiveBooking();
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _activeBooking = activeBooking;
        _isLoading = false;
        _buildMarkers();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    }
  }

  bool _isActiveTripBooking(BookingModel? booking) {
    if (booking == null || booking.tripId != widget.tripId) return false;
    return booking.isPending || booking.isConfirmed;
  }

  Future<BookingModel?> _loadActiveBooking() async {
    try {
      final bookings = await BookingService().getMyBookings();
      for (final booking in bookings) {
        if (_isActiveTripBooking(booking)) return booking;
      }
    } catch (e) {
      debugPrint('Could not load active booking for trip details: $e');
    }
    return null;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_trip != null) {
      _updateMapBounds();
    }
  }

  void _buildMarkers() {
    if (_trip == null) return;
    _markers = {
      Marker(
        markerId: const MarkerId('from'),
        position: LatLng(_trip!.from.latitude, _trip!.from.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _trip!.from.name),
      ),
      Marker(
        markerId: const MarkerId('to'),
        position: LatLng(_trip!.to.latitude, _trip!.to.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _trip!.to.name),
      ),
      if (_liveDriverLocation != null)
        Marker(
          markerId: const MarkerId('driver_live'),
          position: _liveDriverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'موقع السائق المباشر'),
        ),
    };
  }

  void _updateMapBounds() {
    if (_trip == null || _mapController == null) return;

    final fromLatLng = LatLng(_trip!.from.latitude, _trip!.from.longitude);
    final toLatLng = LatLng(_trip!.to.latitude, _trip!.to.longitude);

    final minLat = fromLatLng.latitude < toLatLng.latitude
        ? fromLatLng.latitude
        : toLatLng.latitude;
    final maxLat = fromLatLng.latitude > toLatLng.latitude
        ? fromLatLng.latitude
        : toLatLng.latitude;
    final minLng = fromLatLng.longitude < toLatLng.longitude
        ? fromLatLng.longitude
        : toLatLng.longitude;
    final maxLng = fromLatLng.longitude > toLatLng.longitude
        ? fromLatLng.longitude
        : toLatLng.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الرحلة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الرحلة')),
        body: const Center(child: Text('الرحلة غير موجودة')),
      );
    }

    final trip = _trip!;
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    final activeBookingSeatIndexes = _activeBooking == null
        ? <int>[]
        : BookingSeatFormatter.displaySeatIndexes(_activeBooking!, trip);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الرحلة')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مسار الرحلة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.from.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    // Intermediate stops
                    if (trip.stops.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...trip.stops.asMap().entries.map((entry) {
                        final i = entry.key;
                        final stop = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.radio_button_checked,
                                color: T.secondary(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${i + 1}. ${stop.name}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: T.onSurface(context)
                                        .withValues(alpha: 0.70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                    ] else
                      const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_city, color: T.error(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.to.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    zoom: 10,
                  ),
                  markers: _markers,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  label: 'عرض المسار على الخريطة',
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        RouteNames.tripRouteMap,
                        arguments: trip,
                      );
                    },
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text(
                      'عرض المسار على الخريطة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                      foregroundColor: T.onPrimary(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الرحلة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (trip.distanceKm != null) ...[
                      _DetailRow(
                        icon: Icons.straighten,
                        label: 'مسافة الرحلة',
                        value: '${trip.distanceKm!.toStringAsFixed(1)} كم',
                      ),
                      const Divider(),
                    ],
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'وقت الانطلاق',
                      value:
                          '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.attach_money,
                      label: 'السعر لكل مقعد',
                      value: '${trip.price} ${trip.currency}',
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.event_seat,
                      label: 'المقاعد المتاحة',
                      value: '${trip.availableSeats} من ${trip.totalSeats}',
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.grid_view,
                      label: 'تخطيط المقاعد',
                      value: SeatLayoutHelpers.formatTripSeatLayoutPattern(
                        trip.seatLayout,
                        trip.seats,
                        trip.totalSeats,
                      ),
                    ),
                    if (trip.seatLayout.preventGenderMixing) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.block,
                        label: 'منع الاختلاط',
                        value: 'مفعل',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات السائق',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.person,
                      label: 'الاسم',
                      value: trip.driverName ?? '',
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.phone,
                      label: 'الهاتف',
                      value: trip.driverPhone ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Driver notes card
            if (trip.notes != null && trip.notes!.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            color: T.secondary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ملاحظات السائق',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        trip.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: T.onSurface(context).withValues(alpha: 0.80),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_activeBooking != null) ...[
              const SizedBox(height: 16),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تخطيط المقاعد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SeatLayoutWidget(
                        trip: trip,
                        selectedSeats: activeBookingSeatIndexes,
                        userGender: userModel?.gender,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (userModel != null && trip.carImageUrl != null) ...[
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'صورة السيارة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: trip.carImageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            return Container(
                              height: 200,
                              color: T.outlineVariant(context),
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 48),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (userModel != null &&
                _activeBooking == null &&
                trip.hasAvailableSeats &&
                trip.isUpcoming)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  button: true,
                  label: 'احجز مقعد',
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        RouteNames.seatSelection,
                        arguments: trip.id,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'احجز مقعد',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              )
            else if (userModel != null &&
                _activeBooking == null &&
                !trip.hasAvailableSeats)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: T.error(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: T.error(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد مقاعد متاحة',
                          style: TextStyle(
                            color: T.error(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (userModel != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ChatRatingButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'المحادثة',
                        color: T.primary(context),
                        onTap: () async {
                          final chatService = ChatService();
                          final chatEnabled = await chatService
                              .checkIfChatEnabled(trip.id);

                          if (!chatEnabled) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'لم يتم تفعيل التواصل بعد. يجب على السائق دفع رسوم التواصل أولاً.',
                                  ),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ChatRatingButton(
                        icon: Icons.star_outline,
                        label: 'تقييم',
                        color: AppColors.warning,
                        onTap: () async {
                          if (trip.isPast) {
                            final ratingService = RatingService();
                            final hasRated = await ratingService
                                .hasUserRatedTrip(trip.id);

                            if (hasRated) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'لقد قمت بتقييم هذه الرحلة بالفعل',
                                    ),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                              }
                              return;
                            }

                            final result = await Navigator.pushNamed(
                              context,
                              RouteNames.rating,
                              arguments: {
                                'tripId': trip.id,
                                'trip': trip,
                                'driverId': trip.driverId,
                                'driverName': trip.driverName,
                              },
                            );

                            if (result == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('شكراً لتقييمك!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'يمكنك التقييم بعد انتهاء الرحلة',
                                  ),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketService.unsubscribeFromTripTracking(widget.tripId);
    _trackingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: T.primary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ChatRatingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ChatRatingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: color),
        ),
      ),
    );
  }
}
