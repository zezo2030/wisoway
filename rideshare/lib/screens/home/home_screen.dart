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
import '../../l10n/l10n_extensions.dart';
import '../../widgets/location_picker_widget.dart';
import 'home_drawer.dart';
import 'tabs/home_tab_content.dart';
import 'tabs/driver_home_content.dart';
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
          title: context.l10n.locationServicesDisabledTitle,
          message: context.l10n.locationServicesDisabledMessage,
          onAction: () async {
            await _locationService.openLocationSettings();
            _loadUserLocation();
          },
          actionLabel: context.l10n.enable,
        );
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED') ||
          errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        _showLocationRequirementDialog(
          title: context.l10n.locationPermissionRequiredTitle,
          message: context.l10n.locationPermissionRequiredMessage,
          onAction: () async {
            if (errorStr.contains('PERMANENTLY_DENIED')) {
              await _locationService.openAppSettings();
            } else {
              _loadUserLocation();
            }
          },
          actionLabel: context.l10n.grantPermission,
        );
      }

      setState(() {
        _userLocation = LocationModel(
          name: context.l10n.defaultCityName,
          latitude: 31.9539,
          longitude: 35.9106,
          address: context.l10n.defaultCityAddress,
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
              context.l10n.later,
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
          title: context.l10n.chooseYourLocation,
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

  int _tabCountForRole(bool isDriver) => isDriver ? 3 : 4;

  /// Keeps index in range when role/tab layout changes (e.g. passenger → driver).
  int _safeTabIndex(bool isDriver) {
    final n = _tabCountForRole(isDriver);
    if (_currentIndex < 0 || _currentIndex >= n) return 0;
    return _currentIndex;
  }

  void _syncTabIndexIfNeeded(int safeIndex) {
    if (safeIndex == _currentIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _currentIndex = safeIndex);
    });
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
    final bool isDriver = user?.isDriver == true;
    final int safeIndex = _safeTabIndex(isDriver);
    _syncTabIndexIfNeeded(safeIndex);

    final pages = isDriver
        ? [
            DriverHomeContent(
              user: user,
              userLocation: _userLocation,
              isLoadingLocation: _isLoadingLocation,
              onOpenDrawer: () {},
              onRefreshLocation: _loadUserLocation,
              onChangeLocation: _changeLocation,
              onRefreshData: _refreshHomeData,
            ),
            BookingsTab(user: user),
            ProfileTab(user: user),
          ]
        : [
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
            selectedIndex: safeIndex,
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
              NavigationRailDestination(
                icon: const Icon(IconsaxPlusLinear.home),
                selectedIcon: const Icon(IconsaxPlusBold.home),
                label: Text(context.l10n.home),
              ),
              if (!isDriver)
                NavigationRailDestination(
                  icon: const Icon(IconsaxPlusLinear.search_normal),
                  selectedIcon: const Icon(IconsaxPlusBold.search_normal),
                  label: Text(context.l10n.searchTab),
                ),
              NavigationRailDestination(
                icon: Icon(
                  isDriver
                      ? IconsaxPlusLinear.car
                      : IconsaxPlusLinear.bookmark,
                ),
                selectedIcon: Icon(
                  isDriver ? IconsaxPlusBold.car : IconsaxPlusBold.bookmark,
                  color: T.primary(context),
                ),
                label: Text(
                  isDriver ? context.l10n.myTripsTitle : context.l10n.myBookings,
                ),
              ),
              NavigationRailDestination(
                icon: const Icon(IconsaxPlusLinear.profile),
                selectedIcon: const Icon(IconsaxPlusBold.profile),
                label: Text(context.l10n.profileTabLabel),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: safeIndex, children: pages),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffoldWithBottomNav(BuildContext context, user) {
    final bool isDriver = user?.isDriver == true;
    final int safeIndex = _safeTabIndex(isDriver);
    _syncTabIndexIfNeeded(safeIndex);

    return Scaffold(
      body: Builder(
        builder: (scaffoldBodyContext) {
          final pages = isDriver
              ? [
                  DriverHomeContent(
                    user: user,
                    userLocation: _userLocation,
                    isLoadingLocation: _isLoadingLocation,
                    onOpenDrawer: () =>
                        Scaffold.of(scaffoldBodyContext).openDrawer(),
                    onRefreshLocation: _loadUserLocation,
                    onChangeLocation: _changeLocation,
                    onRefreshData: _refreshHomeData,
                  ),
                  BookingsTab(user: user),
                  ProfileTab(user: user),
                ]
              : [
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
          return IndexedStack(index: safeIndex, children: pages);
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(user, isDriver, safeIndex),
      drawer: HomeDrawer(
        user: user,
        onTabSelect: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(user, bool isDriver, int currentIndex) {
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(IconsaxPlusLinear.home),
        activeIcon: Icon(IconsaxPlusBold.home, color: T.primary(context)),
        label: context.l10n.home,
      ),
      if (!isDriver)
        BottomNavigationBarItem(
          icon: const Icon(IconsaxPlusLinear.search_normal),
          activeIcon: Icon(
            IconsaxPlusBold.search_normal,
            color: T.primary(context),
          ),
          label: context.l10n.searchTab,
        ),
      BottomNavigationBarItem(
        icon: isDriver
            ? const Icon(IconsaxPlusLinear.car)
            : const Icon(IconsaxPlusLinear.bookmark),
        activeIcon: isDriver
            ? Icon(IconsaxPlusBold.car, color: T.primary(context))
            : Icon(IconsaxPlusBold.bookmark, color: T.primary(context)),
        label: isDriver ? context.l10n.myTripsTitle : context.l10n.myBookings,
      ),
      BottomNavigationBarItem(
        icon: const Icon(IconsaxPlusLinear.profile),
        activeIcon: Icon(IconsaxPlusBold.profile, color: T.primary(context)),
        label: context.l10n.profileTitle,
      ),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
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
      items: items,
    );
  }
}
