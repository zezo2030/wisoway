import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/rating_service.dart';
import '../../models/trip_model.dart';
import '../../widgets/rating_widget.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';

class RatingScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;
  final String driverId;
  final String driverName;

  const RatingScreen({
    super.key,
    required this.tripId,
    this.trip,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    if (currentUser == null) {
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

    final hasRated = await _ratingService.hasUserRatedTrip(widget.tripId);

    if (hasRated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لقد قمت بتقييم هذه الرحلة بالفعل'),
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _ratingService.createRating(
        toUserId: widget.driverId,
        tripId: widget.tripId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال التقييم بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييم الرحلة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.outline(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: T.primary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: T.primary(context),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (widget.trip != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${widget.trip!.from.name} → ${widget.trip!.to.name}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: T.onSurfaceVariant(context)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'كيف كانت تجربتك مع السائق؟',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            RatingWidget(
              initialRating: _selectedRating,
              starSize: 48.0,
              onRatingChanged: (rating) {
                setState(() {
                  _selectedRating = rating;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedRating > 0)
              Text(
                _getRatingLabel(_selectedRating),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: T.primary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 48),
            Semantics(
              label: 'حقل تعليق',
              textField: true,
              hint: 'شاركنا رأيك في الرحلة',
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'تعليق (اختياري)',
                  hintText: 'شاركنا رأيك في الرحلة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                label: 'إرسال التقييم',
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'إرسال التقييم',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'سيء جداً';
      case 2:
        return 'سيء';
      case 3:
        return 'متوسط';
      case 4:
        return 'جيد';
      case 5:
        return 'ممتاز';
      default:
        return '';
    }
  }
}
