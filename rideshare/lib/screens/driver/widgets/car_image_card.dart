import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../widgets/common/section_card.dart';

class CarImageCard extends StatelessWidget {
  final TripModel trip;

  const CarImageCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    if (trip.carImageUrl == null) return const SizedBox.shrink();

    return SectionCard(
      title: 'صورة السيارة',
      icon: IconsaxPlusBold.car,
      iconColor: AppColors.teal600,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: trip.carImageUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      IconsaxPlusLinear.danger,
                      size: 48,
                      color: AppColors.slate300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فشل تحميل الصورة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
