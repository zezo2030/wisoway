import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../models/trip_model.dart';
import 'suggested_trip_card.dart';

/// Horizontally scrolling strip of suggested trips with a page indicator.
class SuggestedTripsCarousel extends StatefulWidget {
  final List<TripModel> trips;
  final void Function(TripModel trip) onTripTap;

  const SuggestedTripsCarousel({
    super.key,
    required this.trips,
    required this.onTripTap,
  });

  @override
  State<SuggestedTripsCarousel> createState() => _SuggestedTripsCarouselState();
}

class _SuggestedTripsCarouselState extends State<SuggestedTripsCarousel> {
  static const double _gap = 12;
  static const double _cardHeight = 232;

  final ScrollController _controller = ScrollController();
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncActiveIndex);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncActiveIndex);
    _controller.dispose();
    super.dispose();
  }

  void _syncActiveIndex() {
    if (!_controller.hasClients) return;
    final step = SuggestedTripCard.cardWidth + _gap;
    final index = (_controller.offset / step).round().clamp(
      0,
      widget.trips.length - 1,
    );
    if (index != _activeIndex) setState(() => _activeIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: widget.trips.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              final trip = widget.trips[index];
              return SuggestedTripCard(
                trip: trip,
                onTap: () => widget.onTripTap(trip),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < widget.trips.length; index++)
              _dot(context, index),
          ],
        ),
      ],
    );
  }

  Widget _dot(BuildContext context, int index) {
    final isActive = index == _activeIndex;

    return Container(
      key: ValueKey('suggested-dot-$index'),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive
            ? T.primary(context)
            : T.onSurfaceVariant(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
