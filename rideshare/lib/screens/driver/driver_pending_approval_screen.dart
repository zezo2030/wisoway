import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/vehicle_model.dart';
import '../../widgets/auth/auth_primary_button.dart';

/// Landing screen for a driver whose registration is awaiting admin approval.
///
/// Shows which documents were received and offers a way back into wizard steps
/// 2–3 to fix them while the account is still pending.
class DriverPendingApprovalScreen extends StatefulWidget {
  const DriverPendingApprovalScreen({super.key});

  @override
  State<DriverPendingApprovalScreen> createState() =>
      _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState
    extends State<DriverPendingApprovalScreen> {
  final VehicleService _vehicleService = VehicleService();

  VehicleModel? _vehicle;
  bool _isLoadingVehicle = true;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final vehicle = await _vehicleService.getMyVehicle();
      if (mounted) {
        setState(() {
          _vehicle = vehicle;
          _isLoadingVehicle = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVehicle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              const SizedBox(height: 4),
              Center(
                child: Image.asset(
                  'assets/illustrations/auth/auth_driver_pending_review_hero.png',
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.driverPendingReviewTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.driverPendingReviewBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 22),
              _buildStatusCard(),
              const SizedBox(height: 14),
              _buildEditRow(),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: l10n.driverReturnHome,
                icon: IconsaxPlusLinear.home_2,
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.home,
                  (route) => false,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.signIn,
                        (route) => false,
                      );
                    }
                  },
                  child: Text(
                    l10n.signOut,
                    style: TextStyle(color: T.onSurfaceVariant(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(IconsaxPlusLinear.notification, color: T.onSurface(context)),
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.notifications),
        ),
        Row(
          children: [
            Icon(
              IconsaxPlusLinear.message_question,
              size: 18,
              color: T.primary(context),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.authNeedHelp,
              style: TextStyle(fontSize: 13, color: T.primary(context)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.driverPendingStatusLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.statusPending.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.statusPending,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.driverPendingBadge,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: T.outline(context), height: 1),
          const SizedBox(height: 16),
          Text(
            l10n.driverSubmittedDocs,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoadingVehicle)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              children: [
                _docTile(
                  IconsaxPlusLinear.personalcard,
                  l10n.driverDocLicense,
                  _vehicle?.licenseImageUrl,
                ),
                _docTile(
                  IconsaxPlusLinear.document_text,
                  l10n.driverDocRegistration,
                  _vehicle?.vehicleLicenseImageUrl,
                ),
                _docTile(
                  IconsaxPlusLinear.shield_tick,
                  l10n.driverDocInsurance,
                  _vehicle?.insuranceImageUrl,
                ),
                _docTile(
                  IconsaxPlusLinear.car,
                  l10n.driverDocCarPhoto,
                  _vehicle?.carImageUrl,
                ),
              ],
            ),
          const SizedBox(height: 16),
          _buildRestrictionBanner(),
        ],
      ),
    );
  }

  Widget _docTile(IconData icon, String label, String? url) {
    final received = url != null && url.isNotEmpty;

    return Expanded(
      child: Semantics(
        label: label,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: received
                        ? T.primary(context).withValues(alpha: 0.10)
                        : T.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: received
                        ? T.primary(context)
                        : T.onSurfaceVariant(context),
                  ),
                ),
                if (received)
                  PositionedDirectional(
                    top: -4,
                    end: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.success(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: T.surface(context), width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconsaxPlusBold.shield_tick,
              color: T.primary(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.driverPendingRestrictionTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.driverPendingRestrictionBody,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditRow() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Semantics(
      button: true,
      label: context.l10n.driverEditRegistrationTitle,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            RouteNames.driverCompleteProfile,
            arguments: {'editMode': true},
          );
          if (mounted) _loadVehicle();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: T.outline(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconsaxPlusLinear.edit_2,
                  color: T.primary(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.driverEditRegistrationTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.driverEditRegistrationSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
