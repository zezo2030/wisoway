import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/colors.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: AppRadius.radiusLg,
            boxShadow: AppShadows.card,
          ),
          child: Column(children: _withDividers(context)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(BuildContext context) {
    final list = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        list.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: T.outline(context)),
          ),
        );
      }
      list.add(children[i]);
    }
    return list;
  }
}
