import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _version.isEmpty
        ? context.l10n.loadingVersion
        : context.l10n.versionLabel(
            '$_version${_buildNumber.isNotEmpty ? '+$_buildNumber' : ''}',
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              T.primary(context).withValues(alpha: 0.08),
              T.background(context),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _TopBar(onBack: () => Navigator.pop(context)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: T.surface(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: T.shadow(context).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: T.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        IconsaxPlusBold.car,
                        size: 38,
                        color: T.primary(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'VisionWay',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      versionLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.aboutAppTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _InfoCard(
                title: context.l10n.whatMakesVisionWaySpecial,
                items: [
                  context.l10n.aboutFeatureArabicFirst,
                  context.l10n.aboutFeatureFlexibleManagement,
                  context.l10n.aboutFeatureTrustDesign,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(IconsaxPlusLinear.arrow_right_2),
          style: IconButton.styleFrom(
            backgroundColor: T.surface(context),
            foregroundColor: T.onSurface(context),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          context.l10n.aboutApp,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: T.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: T.primary(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
