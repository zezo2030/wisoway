import 'package:flutter/material.dart';

/// Lets the home screen's tabs (search, bookings/trips, profile) send the user
/// back to the home tab. The tabs live in one IndexedStack, so there is no
/// route underneath them to pop to — "back" has to mean "switch tabs".
class HomeTabScope extends InheritedWidget {
  const HomeTabScope({super.key, required this.goHome, required super.child});

  final VoidCallback goHome;

  static VoidCallback? goHomeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabScope>()?.goHome;

  @override
  bool updateShouldNotify(HomeTabScope oldWidget) => false;
}

/// The back arrow on a home tab's header. Uses the platform back icon, so it
/// points the right way in Arabic and English. Renders nothing outside the home
/// screen, where a tab widget has no home tab to return to.
class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final goHome = HomeTabScope.goHomeOf(context);
    if (goHome == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      color: color,
      icon: const BackButtonIcon(),
      onPressed: goHome,
    );
  }
}
