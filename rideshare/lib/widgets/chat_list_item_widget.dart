import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../core/theme/colors.dart';

class ChatListItemWidget extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;
  final String? tripFromName;
  final String? tripToName;
  final VoidCallback onTap;

  const ChatListItemWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.tripFromName,
    this.tripToName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip route or participants
                  Text(
                    tripFromName != null && tripToName != null
                        ? '$tripFromName → $tripToName'
                        : 'محادثة الرحلة',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Last message
                  if (chat.lastMessage != null)
                    Text(
                      chat.lastMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'لا توجد رسائل بعد',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textDisabled,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time
            if (chat.lastMessageTime != null)
              Text(
                _formatTime(chat.lastMessageTime!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time only
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'أمس';
    } else if (difference.inDays < 7) {
      // This week
      return '${difference.inDays} أيام';
    } else {
      // Older - show date
      return DateFormat('dd/MM').format(timestamp);
    }
  }
}

