import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';

/// A place name with the typed text marked inside it.
///
/// inDrive highlights the part of every result that matched the query, which
/// is what lets the eye skip down a list of near-identical street names. Each
/// whitespace-separated word of the query is matched on its own, so "amman
/// hosp" marks both fragments.
class HighlightedPlaceName extends StatelessWidget {
  const HighlightedPlaceName({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final spans = _spans();

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _spans() {
    final plain = <TextSpan>[TextSpan(text: text, style: style)];
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return plain;

    final lower = text.toLowerCase();
    // Some scripts change length when lowercased; the index map would then be
    // wrong, so highlight nothing rather than mark the wrong characters.
    if (lower.length != text.length) return plain;

    final marked = List<bool>.filled(text.length, false);
    for (final token in tokens) {
      var index = lower.indexOf(token);
      while (index != -1) {
        for (var i = index; i < index + token.length; i++) {
          marked[i] = true;
        }
        index = lower.indexOf(token, index + token.length);
      }
    }
    if (!marked.contains(true)) return plain;

    final highlighted = style.copyWith(
      color: highlightColor,
      fontWeight: FontWeight.bold,
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || marked[i] != marked[start]) {
        spans.add(
          TextSpan(
            text: text.substring(start, i),
            style: marked[start] ? highlighted : style,
          ),
        );
        start = i;
      }
    }
    return spans;
  }
}

/// One row in a place list: pin, name, area, and how far away it is.
///
/// Laid out like inDrive's result row — the distance sits on the name's line
/// at the trailing edge rather than centred against the whole row, so a
/// two-line result keeps its distance next to the name it belongs to.
class PlaceResultRow extends StatelessWidget {
  const PlaceResultRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.query = '',
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Text to mark inside [title]; empty leaves the name unmarked.
  final String query;

  /// Distance label, already formatted.
  final String? trailing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.bodyLarge.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: T.onSurface(context),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 22, color: T.onSurfaceVariant(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  HighlightedPlaceName(
                    text: title,
                    query: query,
                    style: titleStyle,
                    highlightColor: T.primary(context),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Text(
                trailing!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
