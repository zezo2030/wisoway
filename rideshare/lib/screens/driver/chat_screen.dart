import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/chat_service.dart';
import '../../models/chat_model.dart';
import '../../models/trip_model.dart';
import '../../widgets/chat_bubble_widget.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../widgets/common/empty_state.dart';

class DriverChatScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;
  final String? passengerId;
  final String? passengerName;

  const DriverChatScreen({
    super.key,
    required this.tripId,
    this.trip,
    this.passengerId,
    this.passengerName,
  });

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.userModel;

      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'يجب تسجيل الدخول أولاً';
        });
        return;
      }

      ChatModel chat;
      if (widget.passengerId != null) {
        chat = await _chatService.getOrCreateRoomForDriverPassenger(
          widget.tripId,
          widget.passengerId!,
        );
      } else {
        chat = await _chatService.getOrCreateRoomForTrip(widget.tripId);
      }
      setState(() {
        _chatId = chat.id;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل المحادثة: ${e.toString()}';
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      String chatId = _chatId ?? '';

      if (chatId.isEmpty) {
        ChatModel chat;
        if (widget.passengerId != null) {
          chat = await _chatService.getOrCreateRoomForDriverPassenger(
            widget.tripId,
            widget.passengerId!,
          );
        } else {
          chat = await _chatService.getOrCreateRoomForTrip(widget.tripId);
        }
        chatId = chat.id;
        setState(() => _chatId = chatId);
      }

      if (chatId.isEmpty) {
        throw Exception('لا يمكن إنشاء المحادثة');
      }

      await _chatService.sendMessage(
        roomId: chatId,
        text: _messageController.text.trim(),
      );

      _messageController.clear();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.userModel;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('محادثة الرحلة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محادثة الرحلة')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: T.error(context)),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محادثة الرحلة')),
        body: const Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    final chatId = _chatId ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.passengerName != null
                  ? 'محادثة مع ${widget.passengerName}'
                  : 'محادثة الرحلة',
            ),
            if (widget.trip != null && widget.passengerName == null)
              Text(
                '${widget.trip!.from.name} → ${widget.trip!.to.name}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: T.onPrimary(context).withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatId.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'لا توجد رسائل بعد',
                    subtitle: 'ابدأ المحادثة الآن',
                    showCircleBackground: false,
                    iconSize: 64,
                  )
                : StreamBuilder<List<MessageModel>>(
                    stream: _chatService.getChatStream(chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('خطأ: ${snapshot.error}'));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'لا توجد رسائل بعد',
                          subtitle: 'ابدأ المحادثة الآن',
                          showCircleBackground: false,
                          iconSize: 64,
                        );
                      }

                      final reversedMessages = messages.reversed.toList();

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: reversedMessages.length,
                        itemBuilder: (context, index) {
                          final message = reversedMessages[index];
                          final isFromCurrentUser =
                              message.senderId == currentUser.id;

                          return ChatBubbleWidget(
                            message: message,
                            isFromCurrentUser: isFromCurrentUser,
                            currentUserId: currentUser.id,
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: T.surface(context),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        textField: true,
                        label: 'اكتب رسالة',
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'إرسال الرسالة',
                      child: IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        tooltip: 'إرسال',
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        color: T.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
