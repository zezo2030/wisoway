import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/location_model.dart';
import '../../core/theme/colors.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/responsive_layout.dart';
import '../../widgets/location_picker_widget.dart';
import 'home_drawer.dart';
import 'tabs/home_tab_content.dart';
import 'tabs/search_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  LocationModel? _userLocation;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    await notificationProvider.initialize();
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      _loadUserLocation(),
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications(),
    ]);
  }

  Future<void> _loadUserLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      print('❌ Error loading location: $e');
      setState(() => _isLoadingLocation = false);

      final errorStr = e.toString();
      if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
        _showLocationRequirementDialog(
          title: 'خدمات الموقع معطلة',
          message:
              'يرجى تفعيل خدمات الموقع (GPS) لتتمكن من استخدام التطبيق ومشاركة موقعك.',
          onAction: () async {
            await _locationService.openLocationSettings();
            _loadUserLocation();
          },
          actionLabel: 'تفعيل',
        );
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED') ||
          errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        _showLocationRequirementDialog(
          title: 'تصريح الموقع مطلوب',
          message:
              'يحتاج التطبيق إلى تصريح الوصول للموقع لتتمكن من مشاركة رحلاتك.',
          onAction: () async {
            if (errorStr.contains('PERMANENTLY_DENIED')) {
              await _locationService.openAppSettings();
            } else {
              _loadUserLocation();
            }
          },
          actionLabel: 'منح التصريح',
        );
      }

      setState(() {
        _userLocation = LocationModel(
          name: 'عمّان',
          latitude: 31.9539,
          longitude: 35.9106,
          address: 'عمّان، الأردن',
        );
      });
    }
  }

  void _showLocationRequirementDialog({
    required String title,
    required String message,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: GoogleFonts.tajawal()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لاحقاً',
              style: GoogleFonts.tajawal(color: T.onSurfaceVariant(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: T.primary(context),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.tajawal(color: T.onPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر موقعك',
          initialLocation: _userLocation,
          onLocationSelected: (location) {},
        ),
      ),
    );

    if (location != null) {
      setState(() {
        _userLocation = location;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final bool useRail = ResponsiveLayout.useNavigationRail(context);

    if (useRail) {
      return _buildScaffoldWithNavigationRail(context, user);
    }
    return _buildScaffoldWithBottomNav(context, user);
  }

  Widget _buildScaffoldWithNavigationRail(BuildContext context, user) {
    final pages = [
      HomeTabContent(
        user: user,
        userLocation: _userLocation,
        isLoadingLocation: _isLoadingLocation,
        onOpenDrawer: () {},
        onRefreshLocation: _loadUserLocation,
        onChangeLocation: _changeLocation,
        onRefreshData: _refreshHomeData,
      ),
      const SearchTab(),
      BookingsTab(user: user),
      ProfileTab(user: user),
    ];

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
            destinations: [
              const NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.home),
                selectedIcon: Icon(IconsaxPlusBold.home),
                label: Text('الرئيسية'),
              ),
              const NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.search_normal),
                selectedIcon: Icon(IconsaxPlusBold.search_normal),
                label: Text('بحث'),
              ),
              NavigationRailDestination(
                icon: Icon(
                  user?.canCreateTrips == true
                      ? IconsaxPlusLinear.car
                      : IconsaxPlusLinear.bookmark,
                ),
                selectedIcon: Icon(
                  user?.canCreateTrips == true
                      ? IconsaxPlusBold.car
                      : IconsaxPlusBold.bookmark,
                  color: T.primary(context),
                ),
                label: Text(
                  user?.canCreateTrips == true ? 'رحلاتي' : 'حجوزاتي',
                ),
              ),
              const NavigationRailDestination(
                icon: Icon(IconsaxPlusLinear.profile),
                selectedIcon: Icon(IconsaxPlusBold.profile),
                label: Text('البروفايل'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: pages),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffoldWithBottomNav(BuildContext context, user) {
    return Scaffold(
      body: Builder(
        builder: (scaffoldBodyContext) {
          final pages = [
            HomeTabContent(
              user: user,
              userLocation: _userLocation,
              isLoadingLocation: _isLoadingLocation,
              onOpenDrawer: () =>
                  Scaffold.of(scaffoldBodyContext).openDrawer(),
              onRefreshLocation: _loadUserLocation,
              onChangeLocation: _changeLocation,
              onRefreshData: _refreshHomeData,
            ),
            const SearchTab(),
            BookingsTab(user: user),
            ProfileTab(user: user),
          ];
          return IndexedStack(index: _currentIndex, children: pages);
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(user),
      drawer: HomeDrawer(
        user: user,
        onTabSelect: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(user) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
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
      items: [
        BottomNavigationBarItem(
          icon: const Icon(IconsaxPlusLinear.home),
          activeIcon: Icon(IconsaxPlusBold.home, color: T.primary(context)),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: const Icon(IconsaxPlusLinear.search_normal),
          activeIcon: Icon(
            IconsaxPlusBold.search_normal,
            color: T.primary(context),
          ),
          label: 'بحث',
        ),
        BottomNavigationBarItem(
          icon: user?.canCreateTrips == true
              ? const Icon(IconsaxPlusLinear.car)
              : const Icon(IconsaxPlusLinear.bookmark),
          activeIcon: user?.canCreateTrips == true
              ? Icon(IconsaxPlusBold.car, color: T.primary(context))
              : Icon(IconsaxPlusBold.bookmark, color: T.primary(context)),
          label: user?.canCreateTrips == true ? 'رحلاتي' : 'حجوزاتي',
        ),
        BottomNavigationBarItem(
          icon: const Icon(IconsaxPlusLinear.profile),
          activeIcon: Icon(IconsaxPlusBold.profile, color: T.primary(context)),
          label: 'الملف الشخصي',
        ),
      ],
    );
  }
}
