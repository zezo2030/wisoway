import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/notification_icon_button.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.searchForTrip),
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
              context.l10n.searchForTrip,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.showAllAvailableTrips,
              style: TextStyle(
                fontSize: 14,
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: context.l10n.showTrips,
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.tripsList);
                },
                icon: const Icon(IconsaxPlusBold.search_normal),
                label: Text(context.l10n.showTrips),
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
