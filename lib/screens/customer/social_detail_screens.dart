import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../services/storage_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/loading_widget.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _socialService = Get.find<SocialService>();
  final _signalR = Get.find<SignalRService>();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final _messages = <ChatMessageModel>[];
  var _loading = true;
  var _sending = false;
  var _loadingOlder = false;
  var _canLoadOlder = true;
  var _historySkip = 0;
  static const _pageSize = 40;
  int? _roomId;
  String _roomTitle = 'Tin nhắn';
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initRoom();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 80 ||
        _loadingOlder ||
        !_canLoadOlder ||
        _roomId == null) {
      return;
    }
    _loadOlderMessages();
  }

  Future<void> _loadOlderMessages() async {
    setState(() => _loadingOlder = true);
    _historySkip += _pageSize;
    try {
      final older = await _socialService.getChatMessages(
        _roomId!,
        skip: _historySkip,
        top: _pageSize,
      );
      if (older.isEmpty) {
        _canLoadOlder = false;
        _historySkip -= _pageSize;
      } else {
        setState(() => _messages.insertAll(0, older.reversed));
      }
    } catch (e) {
      _historySkip -= _pageSize;
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _initRoom() async {
    final arg = Get.arguments;
    try {
      if (arg is Map) {
        _roomId = arg['roomId'] as int?;
        _roomTitle = arg['title'] as String? ?? _roomTitle;
        _isGroup = arg['isGroup'] as bool? ?? false;
      } else if (arg is int) {
        final room = await _socialService.createDirectChat(arg);
        _roomId = room.id;
        _roomTitle = room.name ?? 'Chat';
      }

      if (_roomId != null) {
        _historySkip = 0;
        _canLoadOlder = true;
        final history = await _socialService.getChatMessages(
          _roomId!,
          top: _pageSize,
        );
        setState(() {
          _messages.clear();
          _messages.addAll(history.reversed);
          if (history.length < _pageSize) _canLoadOlder = false;
        });
        await _signalR.joinChatRoom(_roomId!);
        _signalR.onReceiveMessage((msg) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        });
      }
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      await _signalR.sendChatMessage(_roomId!, text);
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    if (_roomId != null) _signalR.leaveChatRoom(_roomId!);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = Get.find<StorageService>().user?.id;

    return AppScreen(
      title: _roomTitle,
      actions: [
          if (_isGroup)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                if (_roomId != null) {
                  await _socialService.leaveChatRoom(_roomId!);
                  Get.back();
                }
              },
            ),
      ],
      body: _loading
          ? const LoadingWidget()
          : Column(
              children: [
                if (_loadingOlder)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(child: Text('Chưa có tin nhắn'))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                        final isMe = m.senderId == myId;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe && m.senderName != null)
                                  Text(
                                    m.senderName!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                Text(
                                  m.content,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class MomentDetailScreen extends GetView<SocialController> {
  const MomentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final momentId = Get.arguments as int?;
    final userId = Get.find<StorageService>().user?.id;
    MomentModel? moment;
    for (final m in controller.moments) {
      if (m.id == momentId) {
        moment = m;
        break;
      }
    }

    return AppScreen(
      title: 'Chi tiết Moment',
      actions: [
          if (moment != null && moment.userId == userId)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await controller.deleteMoment(moment!.id);
                Get.back();
              },
            ),
      ],
      body: moment == null
          ? const Center(child: Text('Không tìm thấy moment'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(moment.userName?.isNotEmpty == true
                          ? moment.userName![0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(moment.userName ?? ''),
                    subtitle: moment.createdAt != null
                        ? Text(moment.createdAt.toString())
                        : null,
                  ),
                  if (moment.content != null) Text(moment.content!),
                  if (moment.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Image.network(moment.imageUrl!, fit: BoxFit.cover),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(moment.hasReacted
                            ? Icons.favorite
                            : Icons.favorite_border),
                        onPressed: () => controller.reactMoment(moment!.id),
                      ),
                      Text('${moment.reactionCount}'),
                    ],
                  ),
                  const Divider(),
                  Text('Bình luận',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...moment.comments.map((c) {
                    final isOwner = c.userId == userId;
                    return ListTile(
                      title: Text(c.userName ?? 'User'),
                      subtitle: Text(c.content),
                      trailing: isOwner
                          ? PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  final ctrl = TextEditingController(
                                    text: c.content,
                                  );
                                  final newText = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Sửa bình luận'),
                                      content: TextField(controller: ctrl),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, ctrl.text),
                                          child: const Text('Lưu'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newText != null && newText.isNotEmpty) {
                                    await controller.updateComment(
                                      c.id,
                                      newText,
                                    );
                                  }
                                } else if (v == 'delete') {
                                  await controller.deleteComment(c.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa'),
                                ),
                              ],
                            )
                          : null,
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _social = Get.find<SocialService>();
  UserSearchModel? _user;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    if (id != null) _user = await _social.getUserProfile(id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Hồ sơ người dùng',
      body: _loading
          ? const LoadingWidget()
          : _user == null
              ? const Center(child: Text('Không tìm thấy'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _user!.avatarUrl != null
                            ? NetworkImage(_user!.avatarUrl!)
                            : null,
                        child: _user!.avatarUrl == null
                            ? Text(
                                _user!.fullName.isNotEmpty
                                    ? _user!.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 28),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(_user!.fullName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(_user!.email ?? ''),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Get.find<SocialController>()
                            .sendFriendRequest(_user!.id),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Kết bạn'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Get.toNamed(
                          AppRoutes.chatRoom,
                          arguments: _user!.id,
                        ),
                        icon: const Icon(Icons.chat),
                        label: const Text('Nhắn tin'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
