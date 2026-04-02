import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../widgets/notification_icon_button.dart';
import '../../../widgets/common/empty_state.dart';

class MyTripsTab extends StatelessWidget {
  const MyTripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رحلاتي',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'تصفية الرحلات',
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: T.secondary(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            IconsaxPlusLinear.filter,
                            color: T.secondary(context),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const NotificationIconButton(),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(child: _buildTripsList(context)),
          ],
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'رحلة جديدة',
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, RouteNames.createTrip);
          },
          tooltip: 'إنشاء رحلة جديدة',
          backgroundColor: T.primary(context),
          icon: Icon(IconsaxPlusBold.add, color: T.onPrimary(context)),
          label: Text(
            'رحلة جديدة',
            style: TextStyle(
              color: T.onPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList(BuildContext context) {
    final trips = <Map<String, dynamic>>[
      {
        'id': '1',
        'from': 'الرياض',
        'to': 'جدة',
        'status': 'active',
        'date': '2025-12-01',
        'seats': 3,
        'price': 150,
        'currency': 'ريال',
      },
      {
        'id': '2',
        'from': 'جدة',
        'to': 'الدمام',
        'status': 'hidden',
        'date': '2025-12-02',
        'seats': 2,
        'price': 200,
        'currency': 'ريال',
      },
      {
        'id': '3',
        'from': 'مكة',
        'to': 'المدينة',
        'status': 'completed',
        'date': '2025-11-30',
        'seats': 4,
        'price': 180,
        'currency': 'ريال',
      },
    ];

    if (trips.isEmpty) {
      return EmptyState(
        icon: IconsaxPlusLinear.car,
        title: 'لا توجد رحلات',
        subtitle: 'ابدأ بإنشاء رحلة جديدة',
        showCircleBackground: true,
        iconSize: 64,
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, RouteNames.createTrip);
          },
          icon: const Icon(IconsaxPlusBold.add_circle),
          label: const Text('إنشاء رحلة'),
          style: ElevatedButton.styleFrom(backgroundColor: T.primary(context)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _buildTripCard(context, trip);
      },
    );
  }

  Widget _buildTripCard(BuildContext context, Map<String, dynamic> trip) {
    Color getStatusColor() {
      final status = trip['status'] ?? 'active';
      switch (status) {
        case 'active':
          return AppColors.success;
        case 'hidden':
          return AppColors.warning;
        case 'completed':
          return AppColors.info;
        default:
          return T.onSurfaceVariant(context);
      }
    }

    String getStatusText() {
      final status = trip['status'] ?? 'active';
      switch (status) {
        case 'active':
          return 'نشطة';
        case 'hidden':
          return 'مخفية';
        case 'completed':
          return 'مكتملة';
        default:
          return 'غير محدد';
      }
    }

    final statusColor = getStatusColor();
    final statusText = getStatusText();

    final String fromName = trip['from'] ?? 'موقع غير معروف';
    final String toName = trip['to'] ?? 'موقع غير معروف';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: T.outlineVariant(context).withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Semantics(
          button: true,
          label: 'رحلة من $fromName إلى $toName',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {},
            splashColor: statusColor.withValues(alpha: 0.1),
            highlightColor: statusColor.withValues(alpha: 0.05),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trip['status'] == 'active'
                                  ? Icons.circle
                                  : trip['status'] == 'hidden'
                                  ? Icons.visibility_off
                                  : Icons.check_circle,
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            IconsaxPlusLinear.clock,
                            color: null,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trip['date'] ?? 'غير محدد',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: T.onSurfaceVariant(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من',
                              style: TextStyle(
                                fontSize: 13,
                                color: T.onSurfaceVariant(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fromName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: T.onSurface(context),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Icon(
                              IconsaxPlusBold.car,
                              color: T.primary(context),
                              size: 28,
                            ),
                            Container(
                              width: 60,
                              height: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: T
                                    .primary(context)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'إلى',
                              style: TextStyle(
                                fontSize: 13,
                                color: T.onSurfaceVariant(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              toName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: T.onSurface(context),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: List.generate(
                          (constraints.constrainWidth() / 10).floor(),
                          (index) => Expanded(
                            child: Container(
                              height: 1.5,
                              color: index % 2 == 0
                                  ? T
                                        .outlineVariant(context)
                                        .withValues(alpha: 0.3)
                                  : AppColors.transparent,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                Container(
                  decoration: BoxDecoration(
                    color: T.surface(context).withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (trip['price'] != null)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                IconsaxPlusBold.wallet_1,
                                color: AppColors.success,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سعر المقعد',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: T.onSurfaceVariant(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${trip['price']} ${trip['currency'] ?? 'ريال'}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),

                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'المقاعد',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: T.onSurfaceVariant(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${trip['seats'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: T.primary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: T.primary(context).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconsaxPlusBold.people,
                              color: T.primary(context),
                              size: 22,
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
        ),
      ),
    );
  }
}
