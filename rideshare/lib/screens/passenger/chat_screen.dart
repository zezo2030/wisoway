import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/chat_service.dart';
import '../../models/chat_model.dart';
import '../../models/trip_model.dart';
import '../../widgets/chat_bubble_widget.dart';
import '../../core/theme/colors.dart';

class ChatScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;
  final String driverId;
  final String driverName;

  const ChatScreen({
    super.key,
    required this.tripId,
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

      // Check if chat is enabled
      final chatEnabled = await _chatService.checkIfChatEnabled(widget.tripId);

      if (!chatEnabled) {
        setState(() {
          _isLoading = false;
          _chatEnabled = false;
          _errorMessage = 'لم يتم تفعيل التواصل بعد. يجب على السائق دفع رسوم التواصل أولاً.';
        });
        return;
      }

      // Get or create chat room (room id = chat.id)
      final chat = await _chatService.getOrCreateChat(widget.tripId);

      setState(() {
        _chatId = chat.id;
        _chatEnabled = true;
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
    if (_messageController.text.trim().isEmpty || _chatId == null) return;

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
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الرسالة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
          title: Text('محادثة - ${widget.driverName}'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && !_chatEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: Text('محادثة - ${widget.driverName}'),
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
                  color: AppColors.textDisabled,
                ),
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

    if (_chatId == null || currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('محادثة - ${widget.driverName}'),
        ),
        body: const Center(child: Text('خطأ في تحميل المحادثة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('محادثة - ${widget.driverName}'),
            if (widget.trip != null)
              Text(
                '${widget.trip!.from.name} → ${widget.trip!.to.name}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnPrimary.withOpacity(0.8),
                    ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getChatStream(_chatId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد رسائل بعد',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ابدأ المحادثة الآن',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textDisabled,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isFromCurrentUser = message.senderId == currentUser.id;
                    
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
          // Message input
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      color: AppColors.primary,
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



