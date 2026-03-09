import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

/// Widget لعرض جنس المستخدم
class UserGenderDisplay extends StatelessWidget {
  final bool showLabel;
  final TextStyle? textStyle;
  final double iconSize;

  const UserGenderDisplay({
    super.key,
    this.showLabel = true,
    this.textStyle,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        if (user == null) {
          return const SizedBox.shrink();
        }
        
        final isMale = user.isMale;
        final genderText = isMale ? 'ذكر' : 'أنثى';
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة الجنس
            Icon(
              isMale ? Icons.male : Icons.female,
              color: isMale ? Colors.blue : Colors.pink,
              size: iconSize,
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                genderText,
                style: textStyle ?? const TextStyle(fontSize: 14),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Widget لعرض معلومات المستخدم الكاملة
class UserInfoCard extends StatelessWidget {
  const UserInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        if (user == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا يوجد مستخدم مسجل دخول'),
            ),
          );
        }
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // أيقونة الجنس
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: user.isMale 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        user.isMale ? Icons.male : Icons.female,
                        color: user.isMale ? Colors.blue : Colors.pink,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // معلومات المستخدم
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                // معلومات إضافية
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'الجنس',
                  value: user.isMale ? 'ذكر' : 'أنثى',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.badge,
                  label: 'الدور',
                  value: user.role == AppConstants.rolePassenger 
                    ? 'راكب' 
                    : user.role == AppConstants.roleDriver 
                      ? 'سائق' 
                      : 'مدير',
                ),
                if (user.phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.phone,
                    label: 'رقم الهاتف',
                    value: user.phoneNumber,
                  ),
                ],
                if (user.rating > 0) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.star,
                    label: 'التقييم',
                    value: '${user.rating.toStringAsFixed(1)} (${user.totalRatings} تقييم)',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Helper function للحصول على نص الجنس
String getGenderText(String gender) {
  switch (gender) {
    case AppConstants.genderMale:
      return 'ذكر';
    case AppConstants.genderFemale:
      return 'أنثى';
    default:
      return 'غير محدد';
  }
}

/// Helper function للحصول على أيقونة الجنس
IconData getGenderIcon(String gender) {
  switch (gender) {
    case AppConstants.genderMale:
      return Icons.male;
    case AppConstants.genderFemale:
      return Icons.female;
    default:
      return Icons.person;
  }
}

/// Helper function للحصول على لون الجنس
Color getGenderColor(String gender) {
  switch (gender) {
    case AppConstants.genderMale:
      return Colors.blue;
    case AppConstants.genderFemale:
      return Colors.pink;
    default:
      return Colors.grey;
  }
}

