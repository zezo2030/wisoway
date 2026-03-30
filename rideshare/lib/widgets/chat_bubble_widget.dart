import 'package:flutter/material.dart';
import '../core/utils/phone_masker.dart';
import '../models/chat_model.dart';
import '../core/theme/colors.dart';

class ChatBubbleWidget extends StatelessWidget {
  final MessageModel message;
  final bool isFromCurrentUser;
  final String currentUserId;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final maskedText = PhoneMasker.maskPhoneNumbers(message.text);

    final senderInfo = isFromCurrentUser
        ? 'رسالتك'
        : 'رسالة من ${message.senderName}';
    final timeInfo = _formatTime(message.createdAt);

    return Semantics(
      label: '$senderInfo: $maskedText، $timeInfo',
      child: Align(
        alignment: isFromCurrentUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isFromCurrentUser ? T.primary(context) : T.surface(context),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isFromCurrentUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isFromCurrentUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isFromCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: T.onSurfaceVariant(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                maskedText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isFromCurrentUser
                      ? T.onPrimary(context)
                      : T.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isFromCurrentUser
                      ? T.onPrimary(context).withValues(alpha: 0.7)
                      : T.onSurfaceVariant(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
