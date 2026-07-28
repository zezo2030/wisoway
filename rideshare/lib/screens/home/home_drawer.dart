import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../../models/user_model.dart';
import '../../../widgets/common/logout_confirmation_dialog.dart';
import 'widgets/drawer_menu_item.dart';

class HomeDrawer extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<int>? onTabSelect;

  const HomeDrawer({super.key, this.user, this.onTabSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  T.primary(context),
                  T.primary(context).withValues(alpha: 0.8),
                  T.primary(context).withValues(alpha: 0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: T.onPrimary(context),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: T.surface(context),
                          child:
                              user?.photoUrl != null &&
                                  user!.photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user!.photoUrl!,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    errorWidget: (context, url, error) => Icon(
                                      IconsaxPlusBold.profile,
                                      size: 50,
                                      color: T.primary(context),
                                    ),
                                  ),
                                )
                              : Icon(
                                  IconsaxPlusBold.profile,
                                  size: 50,
                                  color: T.primary(context),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: T.onPrimary(context),
                              width: 3,
                            ),
                          ),
                          child: const SizedBox(width: 12, height: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.name ?? context.l10n.userFallback,
                    style: GoogleFonts.tajawal(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: T.onPrimary(context),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (user?.email != null && user!.email.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          IconsaxPlusLinear.sms,
                          size: 14,
                          color: T.onPrimary(context).withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user!.email,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              color: T
                                  .onPrimary(context)
                                  .withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: T.onPrimary(context).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: T.onPrimary(context).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user!.isDriver
                                ? IconsaxPlusBold.car
                                : IconsaxPlusBold.profile_2user,
                            size: 16,
                            color: T.onPrimary(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user!.isDriver
                                ? context.l10n.driver
                                : context.l10n.passenger,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: T.onPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ),
            ),
          ),
          Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.home,
                    title: context.l10n.home,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelect?.call(0);
                    },
                  ),
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.search_normal,
                    title: context.l10n.browseTrips,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.tripsList);
                    },
                  ),
                  if (user?.canCreateTrips == true) ...[
                    DrawerMenuItem(
                      icon: IconsaxPlusLinear.add_circle,
                      title: context.l10n.createTripTitle,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.createTrip);
                      },
                    ),
                    DrawerMenuItem(
                      icon: IconsaxPlusLinear.car,
                      title: context.l10n.myTripsTitle,
                      onTap: () {
                        Navigator.pop(context);
                        final ridesTabIndex = user?.isDriver == true ? 1 : 2;
                        onTabSelect?.call(ridesTabIndex);
                      },
                    ),
                    DrawerMenuItem(
                      icon: IconsaxPlusLinear.wallet,
                      title: context.l10n.myWallet,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.driverWallet);
                      },
                    ),
                  ] else ...[
                    DrawerMenuItem(
                      icon: IconsaxPlusLinear.wallet,
                      title: context.l10n.myWallet,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          RouteNames.passengerWallet,
                        );
                      },
                    ),
                  ],
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.receipt_2,
                    title: context.l10n.pendingChargesTitle,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.pendingCharges);
                    },
                  ),
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.profile,
                    title: context.l10n.profileTitle,
                    onTap: () {
                      Navigator.pop(context);
                      final profileIndex = user?.isDriver == true ? 2 : 3;
                      onTabSelect?.call(profileIndex);
                    },
                  ),
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.setting_2,
                    title: context.l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.settings);
                    },
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  DrawerMenuItem(
                    icon: IconsaxPlusLinear.logout,
                    title: context.l10n.signOut,
                    iconColor: T.error(context),
                    textColor: T.error(context),
                    // Don't pop the drawer first — that disposes this context
                    // before the confirmation dialog can use it.
                    onTap: () => handleLogout(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
