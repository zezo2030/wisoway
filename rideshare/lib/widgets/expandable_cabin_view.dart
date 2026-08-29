import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../core/theme/colors.dart';
import '../models/vehicle_art.dart';
import 'vehicle_cabin_view.dart';

/// A vehicle cabin shown small enough to sit inside a card, which opens
/// full-screen when tapped.
///
/// Vehicle artwork is portrait and runs as tall as 1:2, so a bus squeezed into
/// a card is a thumbnail: good for saying *which* vehicle this is, useless for
/// choosing a seat. The small view is therefore a target, and the real picking
/// happens full-screen.
///
/// Seat state lives with the screen using this widget, not here. Because the
/// expanded view is a separate route, a `setState` on the screen behind it does
/// not rebuild it — so [seatBuilder] is handed a `refresh` callback to call
/// after it mutates that state, keeping the two in step.
class ExpandableCabinView extends StatelessWidget {
  const ExpandableCabinView({
    super.key,
    required this.art,
    required this.title,
    required this.seatBuilder,
    this.thumbnailWidth = 170,
    this.bottomBar,
    this.expandedBottomBarBuilder,
  });

  final VehicleArt art;

  /// Shown in the expanded view's app bar and as the thumbnail's accessible
  /// name.
  final String title;

  /// Builds one seat, given its 1-based display number. Call `refresh` after
  /// changing the screen's own state so the expanded view redraws; it is a
  /// no-op in the thumbnail, where the screen rebuilds anyway.
  final Widget Function(
    BuildContext context,
    int seatNumber,
    VoidCallback refresh,
  ) seatBuilder;

  final double thumbnailWidth;

  /// Optional controls drawn under the thumbnail.
  final Widget? bottomBar;

  /// Optional controls pinned to the bottom of the expanded view, where they
  /// stay reachable while a long vehicle scrolls.
  ///
  /// A builder, not a widget: the expanded view is pushed once and would
  /// otherwise keep showing whatever these controls read at push time. Rebuilt
  /// on every `refresh`, so it must read live state for the same reason
  /// [seatBuilder] must.
  final Widget Function(BuildContext context, VoidCallback refresh)?
      expandedBottomBarBuilder;

  @override
  Widget build(BuildContext context) {
    final thumbnail = Stack(
      alignment: Alignment.bottomRight,
      children: [
        // The cabin must not mirror in Arabic — the driver sits on the left.
        Directionality(
          textDirection: TextDirection.ltr,
          child: VehicleCabinView(
            art: art,
            maxWidth: thumbnailWidth,
            seatBuilder: (context, n) => seatBuilder(context, n, () {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: T.primary(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconsaxPlusLinear.maximize_4,
              size: 14,
              color: T.onPrimary(context),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        // The whole thumbnail opens the picker, not just the badge on it.
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _ExpandedCabinPage(
              art: art,
              title: title,
              seatBuilder: seatBuilder,
              bottomBarBuilder: expandedBottomBarBuilder,
            ),
          ),
        ),
        child: bottomBar == null
            ? thumbnail
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [thumbnail, const SizedBox(height: 8), bottomBar!],
              ),
      ),
    );
  }
}

class _ExpandedCabinPage extends StatefulWidget {
  const _ExpandedCabinPage({
    required this.art,
    required this.title,
    required this.seatBuilder,
    this.bottomBarBuilder,
  });

  final VehicleArt art;
  final String title;
  final Widget Function(BuildContext, int, VoidCallback) seatBuilder;
  final Widget Function(BuildContext, VoidCallback)? bottomBarBuilder;

  @override
  State<_ExpandedCabinPage> createState() => _ExpandedCabinPageState();
}

class _ExpandedCabinPageState extends State<_ExpandedCabinPage> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: VehicleCabinView(
                    art: widget.art,
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                    seatBuilder: (context, n) =>
                        widget.seatBuilder(context, n, _refresh),
                  ),
                ),
              ),
            ),
            if (widget.bottomBarBuilder != null)
              Material(
                elevation: 8,
                color: T.surface(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: widget.bottomBarBuilder!(context, _refresh),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
