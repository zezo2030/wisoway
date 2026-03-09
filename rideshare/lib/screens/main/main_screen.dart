import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/route_names.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/my_trips_tab.dart';
import 'tabs/profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const MyTripsTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: _getAppBarTitle(),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (user != null)
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                final unreadCount = provider.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(IconsaxPlusLinear.notification),
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.notifications);
                      },
                      tooltip: 'الإشعارات',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(IconsaxPlusLinear.home),
              activeIcon: Icon(IconsaxPlusBold.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(IconsaxPlusLinear.car),
              activeIcon: Icon(IconsaxPlusBold.car),
              label: 'رحلاتي',
            ),
            BottomNavigationBarItem(
              icon: Icon(IconsaxPlusLinear.profile),
              activeIcon: Icon(IconsaxPlusBold.profile),
              label: 'البروفايل',
            ),
          ],
        ),
      ),
    );
  }

  Widget _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return const Text('الرئيسية');
      case 1:
        return const Text('رحلاتي');
      case 2:
        return const Text('البروفايل');
      default:
        return const Text('RideShare');
    }
  }
}
