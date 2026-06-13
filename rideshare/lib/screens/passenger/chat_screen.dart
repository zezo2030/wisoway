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
import '../../l10n/l10n_extensions.dart';

class ChatScreen extends StatefulWidget {
  final String tripId;
  final String? chatRoomId;
  final TripModel? trip;
  final String driverId;
  final String driverName;

  const ChatScreen({
    super.key,
    required this.tripId,
    this.chatRoomId,
    this.trip,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _chatEnabled = false;
  // 0 = none, 1 = must sign in, 2 = chat not enabled, 3 = load error
  int _errorCode = 0;
  String? _loadErrorDetail;
  bool _readOnly = false;

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
          _errorCode = 1;
        });
        return;
      }

      if (widget.chatRoomId != null && widget.chatRoomId!.isNotEmpty) {
        final chat = await _chatService.getRoomById(widget.chatRoomId!);
        setState(() {
          _chatId = chat.id;
          _chatEnabled = true;
          _readOnly = chat.isClosedForSending;
          _isLoading = false;
        });
        return;
      }

      final chatEnabled = await _chatService.checkIfChatEnabled(widget.tripId);

      if (!chatEnabled) {
        setState(() {
          _isLoading = false;
          _chatEnabled = false;
          _errorCode = 2;
        });
        return;
      }

      final chat = await _chatService.getOrCreateChat(widget.tripId);

      setState(() {
        _chatId = chat.id;
        _chatEnabled = true;
        _readOnly = chat.isClosedForSending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorCode = 3;
        _loadErrorDetail = e.toString();
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatId == null) return;
    if (_readOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatClosedForSending)),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        roomId: _chatId!,
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
        appBar: AppBar(
          title: Text(context.l10n.chatTitleWithDriver(widget.driverName)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCode != 0 && !_chatEnabled) {
      final errorText = _errorCode == 1
          ? context.l10n.errorMustSignInFirst
          : _errorCode == 2
              ? context.l10n.chatNotEnabledYet
              : context.l10n.chatLoadError(_loadErrorDetail ?? '');
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.chatTitleWithDriver(widget.driverName)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: T.outlineVariant(context),
                ),
                const SizedBox(height: 16),
                Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_chatId == null || currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.chatTitleWithDriver(widget.driverName)),
        ),
        body: Center(child: Text(context.l10n.chatLoadErrorShort)),
      );
    }

    final readOnly = _readOnly;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.chatTitleWithDriver(widget.driverName)),
            if (widget.trip != null)
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
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getChatStream(_chatId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      context.l10n.errorWithMessage('${snapshot.error}'),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: context.l10n.chatNoMessagesYet,
                    subtitle: context.l10n.chatStartConversationNow,
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
          if (readOnly)
            Container(
              width: double.infinity,
              color: T.surfaceVariant(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                context.l10n.chatClosedForSending,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: T.onSurfaceVariant(context),
                    ),
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
                        label: context.l10n.chatTypeMessageLabel,
                        child: TextField(
                          controller: _messageController,
                          enabled: !readOnly,
                          decoration: InputDecoration(
                            hintText: readOnly
                                ? context.l10n.chatClosedForSending
                                : context.l10n.chatTypeMessageHint,
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
                          onSubmitted: (_) {
                            if (!readOnly) _sendMessage();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSending || readOnly
                          ? null
                          : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      color: T.primary(context),
                      tooltip: context.l10n.chatSendMessageTooltip,
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
