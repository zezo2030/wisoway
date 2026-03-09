import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../widgets/notification_icon_button.dart';

class MyTripsTab extends StatelessWidget {
  const MyTripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'رحلاتي',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          IconsaxPlusLinear.filter,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const NotificationIconButton(),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(child: _buildTripsList(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, RouteNames.createTrip);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(IconsaxPlusBold.add, color: Colors.white),
        label: const Text(
          'رحلة جديدة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTripsList(BuildContext context) {
    // TODO: Replace with actual trips data
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusLinear.car,
                size: 64,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد رحلات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإنشاء رحلة جديدة',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.createTrip);
              },
              icon: const Icon(IconsaxPlusBold.add_circle),
              label: const Text('إنشاء رحلة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
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
          return AppColors.textSecondary;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // TODO: Navigate to trip details
          },
          splashColor: statusColor.withOpacity(0.1),
          highlightColor: statusColor.withOpacity(0.05),
          child: Column(
            children: [
              // ---------------- TOP PART: Status & Time ----------------
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
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
                    // Date & Time
                    Row(
                      children: [
                        const Icon(
                          IconsaxPlusLinear.clock,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trip['date'] ?? 'غير محدد',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ---------------- MIDDLE PART: Route (Horizontal) ----------------
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // FROM
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'من',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fromName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // CAR ICON Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const Icon(
                            IconsaxPlusBold.car,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          Container(
                            width: 60,
                            height: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // TO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'إلى',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            toName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
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

              // Dotted Divider
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
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ---------------- BOTTOM PART: Price & Seats ----------------
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.6),
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
                    // Price
                    if (trip['price'] != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
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
                              const Text(
                                'سعر المقعد',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
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

                    // Seats
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'المقاعد',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${trip['seats'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            IconsaxPlusBold.people,
                            color: AppColors.primary,
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
    );
  }
}
