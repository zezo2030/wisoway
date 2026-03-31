import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/localization_service.dart';
import '../../../core/theme/colors.dart';

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
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.rideshare.app',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'https://play.google.com/store/apps/details?id=com.rideshare.app',
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();
    final isArabic = localizationService.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? 'حول التطبيق' : 'About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Icon(IconsaxPlusBroken.car, size: 80, color: T.primary(context)),
          const SizedBox(height: 16),
          Text(
            'RideShare',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_version.isNotEmpty)
            Text(
              isArabic
                  ? 'الإصدار $_version+$_buildNumber'
                  : 'Version $_version+$_buildNumber',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: T.onSurfaceVariant(context),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'منصة مشاركة الرحلات' : 'Ride sharing platform',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: IconsaxPlusBroken.star,
                  title: isArabic ? 'تقييم التطبيق' : 'Rate App',
                  onTap: _rateApp,
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(
                  icon: IconsaxPlusBroken.export_2,
                  title: isArabic ? 'مشاركة التطبيق' : 'Share App',
                  onTap: _shareApp,
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(
                  icon: IconsaxPlusBroken.document,
                  title: isArabic ? 'التراخيص' : 'Licenses',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LicensePage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            isArabic
                ? 'صنع بـ \u2764\uFE0F في مصر'
                : 'Made with \u2764\uFE0F in Egypt',
            style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: T.primary(context), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: T.onSurface(context),
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              size: 16,
              color: T.onSurfaceVariant(context),
            ),
          ],
        ),
      ),
    );
  }
}
