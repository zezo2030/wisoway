import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/notification_icon_button.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث عن رحلة'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: AppColors.transparent,
              iconColor: T.onSurface(context),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconsaxPlusLinear.search_normal,
              size: 80,
              color: T.onSurfaceVariant(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'ابحث عن رحلة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'عرض جميع الرحلات المتاحة',
              style: TextStyle(
                fontSize: 14,
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'عرض الرحلات',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.tripsList);
                },
                icon: const Icon(IconsaxPlusBold.search_normal),
                label: const Text('عرض الرحلات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.primary(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
