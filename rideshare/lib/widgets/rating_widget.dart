import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class RatingWidget extends StatefulWidget {
  final int initialRating;
  final bool readOnly;
  final double starSize;
  final ValueChanged<int>? onRatingChanged;

  const RatingWidget({
    super.key,
    this.initialRating = 0,
    this.readOnly = false,
    this.starSize = 32.0,
    this.onRatingChanged,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  void didUpdateWidget(RatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _currentRating = widget.initialRating;
    }
  }

  void _onStarTap(int rating) {
    if (widget.readOnly) return;

    setState(() {
      _currentRating = rating;
    });

    widget.onRatingChanged?.call(rating);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= _currentRating;

        return Semantics(
          button: !widget.readOnly,
          label:
              '$starIndex ${starIndex == 1 ? 'نجمة' : 'نجوم'}${isFilled ? ' (مختارة)' : ''}',
          child: GestureDetector(
            onTap: () => _onStarTap(starIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(
                isFilled ? Icons.star : Icons.star_border,
                color: isFilled ? AppColors.warning : T.outlineVariant(context),
                size: widget.starSize,
              ),
            ),
          ),
        );
      }),
    );
  }
}
