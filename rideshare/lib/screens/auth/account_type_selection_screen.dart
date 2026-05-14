import 'package:flutter/material.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';

class AccountTypeSelectionScreen extends StatefulWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  State<AccountTypeSelectionScreen> createState() =>
      _AccountTypeSelectionScreenState();
}

class _AccountTypeSelectionScreenState extends State<AccountTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: T.onSurface(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight;
              final cardHeight = (viewportHeight * 0.28).clamp(210.0, 280.0);

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewportHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header section.
                        const SizedBox(height: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: T
                                    .primary(context)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_circle,
                                size: 60,
                                color: T.primary(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'اختر نوع الحساب',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: T.onSurface(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ما نوع الحساب الذي تريد إنشاءه؟',
                              style: TextStyle(
                                fontSize: 14,
                                color: T.onSurfaceVariant(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Cards section.
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              SizedBox(
                                height: cardHeight,
                                child: _buildAccountTypeCard(
                                  context: context,
                                  icon: Icons.person,
                                  title: 'راكب',
                                  description: 'احجز رحلاتك بسهولة',
                                  color: T.primary(context),
                                  onTap: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      RouteNames.signUp,
                                      arguments: {'accountType': 'passenger'},
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: cardHeight,
                                child: _buildAccountTypeCard(
                                  context: context,
                                  icon: Icons.drive_eta,
                                  title: 'سائق',
                                  description: 'أنشئ رحلاتك واكسب المال',
                                  color: T.secondary(context),
                                  onTap: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      RouteNames.driverSignUp,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Footer section.
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'لديك حساب بالفعل؟ ',
                                style: TextStyle(
                                  color: T.onSurfaceVariant(context),
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    RouteNames.signIn,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: T.primary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: Semantics(
          button: true,
          label: '$title - $description',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 220;

                final verticalPadding = isCompact ? 8.0 : 16.0;
                final iconPadding = isCompact ? 10.0 : 14.0;
                final iconSize = isCompact ? 28.0 : 36.0;
                final titleSize = isCompact ? 19.0 : 22.0;
                final descriptionSize = isCompact ? 11.0 : 13.0;
                final chipFontSize = isCompact ? 11.0 : 12.0;
                final chipIconSize = isCompact ? 14.0 : 16.0;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          size: iconSize,
                          color: AppColors.white,
                        ),
                      ),
                      SizedBox(height: isCompact ? 6 : 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isCompact ? 2 : 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: descriptionSize,
                          color: T.onSurfaceVariant(context),
                          height: isCompact ? 1.2 : 1.35,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isCompact ? 6 : 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 14 : 16,
                          vertical: isCompact ? 5 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ابدأ الآن',
                              style: TextStyle(
                                fontSize: chipFontSize,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward,
                              size: chipIconSize,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
