import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/feature_controllers.dart';
import '../models/social_models.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_helper.dart';
import 'glass_widgets.dart';
import 'moment_card.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class CommentBottomSheet extends StatefulWidget {
  final MomentModel moment;

  const CommentBottomSheet({super.key, required this.moment});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _socialController = Get.find<SocialController>();
  final _storage = Get.find<StorageService>();
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  late MomentModel _moment;
  List<SocialCommentModel> _comments = [];
  bool _sendingComment = false;
  int? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _moment = widget.moment;
    _comments = List<SocialCommentModel>.from(_moment.comments);
  }

  int get _currentUserId => _socialController.currentUserId;

  MomentModel? _findInFeed(int id) {
    for (final m in _socialController.moments) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _editComment(SocialCommentModel c) {
    setState(() {
      _editingCommentId = c.id;
      _commentController.text = c.comment;
    });
    _commentFocusNode.requestFocus();
  }

  String get _myName {
    try {
      final dynamic u = _storage.user;
      final dynamic n = u?.fullName;
      if (n is String && n.trim().isNotEmpty) return n;
    } catch (_) {}
    return 'You';
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    final isVi = Get.locale?.languageCode == 'vi';

    if (diff.inDays > 0)
      return isVi ? '${diff.inDays} ngày' : '${diff.inDays} d';
    if (diff.inHours > 0)
      return isVi ? '${diff.inHours} giờ' : '${diff.inHours} h';
    if (diff.inMinutes > 0)
      return isVi ? '${diff.inMinutes} phút' : '${diff.inMinutes} m';
    return isVi ? 'Vừa xong' : 'Just now';
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      if (_editingCommentId != null) {
        final editingId = _editingCommentId!;
        if (editingId > 0) {
          try {
            await _socialController.updateComment(editingId, text);
          } catch (e) {
            SnackbarHelper.error('sc_cmt_err_update'.tr);
            return;
          }
        }
        setState(() {
          _comments = _comments
              .map((c) => c.id == editingId
                  ? SocialCommentModel(
                      id: c.id,
                      momentId: c.momentId,
                      userId: c.userId,
                      userName: c.userName,
                      avatarUrl: c.avatarUrl,
                      comment: text,
                      timestamp: c.timestamp,
                    )
                  : c)
              .toList();
          _editingCommentId = null;
        });
      } else {
        final ok = await _socialController.commentMoment(_moment.id, text);
        if (ok != null) {
          final added = SocialCommentModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            momentId: _moment.id,
            userId: _currentUserId,
            userName: _myName,
            avatarUrl: _storage.user?.avatarUrl,
            comment: text,
            timestamp: DateTime.now(),
          );
          setState(() {
            _comments = [..._comments, added];
            _moment = _moment.copyWith(comments: _comments);
          });
        } else {
          SnackbarHelper.error('sc_cmt_err_post'.tr);
          return;
        }
      }
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _deleteComment(SocialCommentModel c) async {
    if (c.id > 0) {
      await _socialController.deleteComment(c.id);
    }
    if (mounted) {
      setState(() => _comments.removeWhere((x) => x.id == c.id));
    }
  }

  void _showReportDialog(
      BuildContext context, String contentType, int targetId) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    var isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  '${contentType == 'Moment' ? 'sc_report_moment'.tr : 'sc_report_comment'.tr}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration:
                          InputDecoration(labelText: 'sc_report_reason'.tr),
                      items: [
                        DropdownMenuItem(
                            value: 'Spam', child: Text('sc_report_spam'.tr)),
                        DropdownMenuItem(
                            value: 'sc_report_hate'.tr,
                            child: Text('sc_report_hate'.tr)),
                        DropdownMenuItem(
                            value: 'Harassment',
                            child: Text('sc_report_harassment'.tr)),
                        DropdownMenuItem(
                            value: 'Violence',
                            child: Text('sc_report_violence'.tr)),
                        DropdownMenuItem(
                            value: 'Other', child: Text('sc_report_other'.tr)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: InputDecoration(
                        labelText: 'sc_report_details'.tr,
                        hintText: 'sc_report_details_hint'.tr,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: Text('sc_report_cancel'.tr),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          setDialogState(() => isSending = true);
                          final ok = await _socialController.reportContent(
                            contentType: contentType,
                            targetId: targetId,
                            reason: selectedReason,
                            details: detailsController.text.trim().isNotEmpty
                                ? detailsController.text.trim()
                                : null,
                          );
                          setDialogState(() => isSending = false);
                          if (ok) {
                            Navigator.pop(context);
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('sc_report_submit'.tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.only(
              top: 8,
              left: 0,
              right: 0,
              bottom: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'sc_cmt_title'
                              .trParams({'count': _comments.length.toString()}),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: Colors.black54,
                          onPressed: () => Navigator.pop(context),
                          padding: const EdgeInsets.all(4),
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Content
                Expanded(
                  child: CustomScrollView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      if (_comments.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'sc_cmt_empty'.tr,
                                style: TextStyle(color: AppColors.textTertiary),
                              ),
                            ),
                          ),
                        ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = _comments[index];
                            return GestureDetector(
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => SimpleDialog(
                                    backgroundColor: Colors.white,
                                    children: [
                                      if (c.userId == _currentUserId) ...[
                                        SimpleDialogOption(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _editComment(c);
                                          },
                                          child: Text('sc_menu_edit'.tr,
                                              style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16)),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _deleteComment(c);
                                          },
                                          child: Text('sc_btn_delete'.tr,
                                              style: const TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 16)),
                                        ),
                                      ],
                                      if (c.userId != _currentUserId)
                                        SimpleDialogOption(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _showReportDialog(
                                                context, 'Comment', c.id);
                                          },
                                          child: Text('sc_menu_report'.tr,
                                              style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16)),
                                        ),
                                    ],
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.brandLight,
                                      backgroundImage: (c.avatarUrl != null &&
                                              c.avatarUrl!.isNotEmpty)
                                          ? CachedNetworkImageProvider(
                                              c.avatarUrl!)
                                          : null,
                                      child: (c.avatarUrl == null ||
                                              c.avatarUrl!.isEmpty)
                                          ? const Icon(Icons.person,
                                              size: 20, color: AppColors.brand)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.userName ?? 'User',
                                            style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            c.comment,
                                            style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                _formatTime(c.timestamp),
                                                style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _comments.length,
                        ),
                      ),
                    ],
                  ),
                ),

                // Composer
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      if (_editingCommentId != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.error),
                          onPressed: () {
                            setState(() {
                              _editingCommentId = null;
                              _commentController.clear();
                              FocusScope.of(context).unfocus();
                            });
                          },
                        ),

                      // Current User Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.brandLight,
                        backgroundImage: (_storage.user?.avatarUrl != null &&
                                _storage.user!.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(
                                _storage.user!.avatarUrl!)
                            : null,
                        child: (_storage.user?.avatarUrl == null ||
                                _storage.user!.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person,
                                size: 20, color: AppColors.brand)
                            : null,
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.only(
                              left: 16, right: 4, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
                                  textInputAction: TextInputAction.send,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _submitComment(),
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 15),
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    hintText: _editingCommentId != null
                                        ? 'sc_cmt_edit_hint'.tr
                                        : 'sc_cmt_add_hint'.tr,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    hintStyle: const TextStyle(
                                        color: Colors.black54, fontSize: 15),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Send Button
                              _sendingComment
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.brand),
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap:
                                          _commentController.text.trim().isEmpty
                                              ? null
                                              : _submitComment,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _commentController.text
                                                  .trim()
                                                  .isEmpty
                                              ? Colors.transparent
                                              : AppColors.brand,
                                        ),
                                        child: Icon(Icons.arrow_upward_rounded,
                                            color: _commentController.text
                                                    .trim()
                                                    .isEmpty
                                                ? AppColors.textTertiary
                                                : Colors.white,
                                            size: 20),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
