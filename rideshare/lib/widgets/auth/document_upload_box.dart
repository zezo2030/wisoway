import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Dashed upload area for a single registration document.
///
/// Shows the picked [file] when present, otherwise the already uploaded
/// [previewUrl] (edit mode), otherwise the dashed empty state with the accepted
/// formats hint.
class DocumentUploadBox extends StatelessWidget {
  const DocumentUploadBox({
    super.key,
    required this.label,
    required this.onTap,
    this.file,
    this.previewUrl,
    this.hint,
  });

  final String label;
  final VoidCallback onTap;
  final File? file;
  final String? previewUrl;

  /// Call-to-action inside the empty box; defaults to the generic upload copy.
  final String? hint;

  bool get _hasContent => file != null || (previewUrl?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: context.l10n.uploadFileLabel(label),
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: _hasContent
                  ? _buildPreview(context)
                  : _buildEmptyState(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: file != null
              ? Image.file(file!, fit: BoxFit.cover)
              : Image.network(
                  previewUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: T.surfaceVariant(context),
                    alignment: Alignment.center,
                    child: Icon(
                      IconsaxPlusLinear.gallery_slash,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ),
        ),
        PositionedDirectional(
          top: 8,
          end: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: T.primary(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 16, color: T.onPrimary(context)),
          ),
        ),
        PositionedDirectional(
          bottom: 8,
          start: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.l10n.tapToChange,
              style: const TextStyle(fontSize: 11, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: T.primary(context).withValues(alpha: 0.45),
        radius: 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: T.primary(context).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.primary(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                IconsaxPlusBold.document_upload,
                size: 26,
                color: T.onPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hint ?? context.l10n.tapToUpload,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.l10n.documentFormatsHint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded dashed outline; Flutter has no dashed BorderSide out of the box.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 7;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
