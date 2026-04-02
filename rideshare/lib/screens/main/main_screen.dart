import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/responsive_layout.dart';
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
    final bool useRail = ResponsiveLayout.useNavigationRail(context);

    if (useRail) {
      return _buildScaffoldWithNavigationRail(context, user);
    }
    return _buildScaffoldWithBottomNav(context, user);
  }

  Widget _buildScaffoldWithNavigationRail(BuildContext context, user) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: T.surface(context),
            selectedIconTheme: IconThemeData(color: T.primary(context)),
            selectedLabelTextStyle: TextStyle(
              color: T.primary(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedIconTheme: IconThemeData(
              color: T.onSurfaceVariant(context),
            ),
            unselectedLabelTextStyle: TextStyle(
              color: T.onSurfaceVariant(context),
              fontSize: 12,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: T.primary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconsaxPlusBold.car,
                      color: T.primary(context),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.home),
                selectedIcon: Icon(IconsaxPlusBold.home),
                label: Text('الرئيسية'),
              ),
              NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.car),
                selectedIcon: Icon(IconsaxPlusBold.car),
                label: Text('رحلاتي'),
              ),
              NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.profile),
                selectedIcon: Icon(IconsaxPlusBold.profile),
                label: Text('البروفايل'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(context, user),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _tabs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, user) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        border: Border(
          bottom: BorderSide(color: T.outlineVariant(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          _getAppBarTitle(),
          const Spacer(),
          if (user != null)
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                final unreadCount = provider.unreadCount;
                return Stack(
                  children: [
                    Semantics(
                      button: true,
                      label: 'الإشعارات',
                      child: IconButton(
                        icon: const Icon(IconsaxPlusLinear.notification),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.notifications,
                          );
                        },
                        tooltip: 'الإشعارات',
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: T.error(context),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: TextStyle(
                              color: T.onError(context),
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
    );
  }

  Widget _buildScaffoldWithBottomNav(BuildContext context, user) {
    return Scaffold(
      appBar: AppBar(
        title: _getAppBarTitle(),
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        actions: [
          if (user != null)
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                final unreadCount = provider.unreadCount;
                return Stack(
                  children: [
                    Semantics(
                      button: true,
                      label: 'الإشعارات',
                      child: IconButton(
                        icon: const Icon(IconsaxPlusLinear.notification),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.notifications,
                          );
                        },
                        tooltip: 'الإشعارات',
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: T.error(context),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: TextStyle(
                              color: T.onError(context),
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
              color: AppColors.black.withValues(alpha: 0.1),
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
          backgroundColor: T.surface(context),
          selectedItemColor: T.primary(context),
          unselectedItemColor: T.onSurfaceVariant(context),
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
