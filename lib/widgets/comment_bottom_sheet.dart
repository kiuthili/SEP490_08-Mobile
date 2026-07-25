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
                      decoration: InputDecoration(
                          labelText: 'sc_report_reason'.tr),
                      items: [
                        DropdownMenuItem(
                            value: 'Spam', child: Text('sc_report_spam'.tr)),
                        DropdownMenuItem(
                            value: 'sc_report_hate'.tr, child: Text('sc_report_hate'.tr)),
                        DropdownMenuItem(
                            value: 'Harassment',
                            child: Text('sc_report_harassment'.tr)),
                        DropdownMenuItem(
                            value: 'Violence', child: Text('sc_report_violence'.tr)),
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
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          color: Colors.white.withValues(alpha: 0.85),
          blur: 24,
          padding: EdgeInsets.only(
            top: 8,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Flexible(
                child: CustomScrollView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MomentCard(
                          moment: _moment,
                          currentUserId: _currentUserId,
                          onDelete: (id) async {
                            await _socialController.deleteMoment(id);
                            Get.back();
                          },
                          onLike: (isLike) async {
                            if (_moment.isLikedByMe == isLike) return;

                            final newCount =
                                (_moment.reactionCount + (isLike ? 1 : -1))
                                    .clamp(0, 1 << 30)
                                    .toInt();
                            setState(() {
                              _moment = _moment.copyWith(
                                isLikedByMe: isLike,
                                reactionCount: newCount,
                              );
                            });

                            await _socialController.reactMoment(
                                _moment.id, isLike);
                            final updated = _findInFeed(_moment.id);
                            if (updated != null && mounted) {
                              setState(() => _moment = updated);
                            }
                          },
                          onReport: (id) =>
                              _showReportDialog(context, 'Moment', id),
                          isDetail: true,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'sc_cmt_title'.trParams({'count': _comments.length.toString()}),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ),
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
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.brandLight,
                              backgroundImage: (c.avatarUrl != null &&
                                      c.avatarUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(c.avatarUrl!)
                                  : null,
                              child:
                                  (c.avatarUrl == null || c.avatarUrl!.isEmpty)
                                      ? const Icon(Icons.person,
                                          size: 20, color: AppColors.brand)
                                      : null,
                            ),
                            title: Text(
                              c.userName ?? 'User',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(c.comment),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  size: 20, color: Colors.black45),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  _editComment(c);
                                } else if (val == 'delete') {
                                  await _deleteComment(c);
                                } else if (val == 'report') {
                                  _showReportDialog(context, 'Comment', c.id);
                                }
                              },
                              itemBuilder: (_) => [
                                if (c.userId == _currentUserId) ...[
                                  PopupMenuItem(
                                      value: 'edit', child: Text('sc_menu_edit'.tr)),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('sc_btn_delete'.tr,
                                        style:
                                            TextStyle(color: AppColors.error)),
                                  ),
                                ],
                                if (c.userId != _currentUserId)
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text('sc_menu_report'.tr),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        childCount: _comments.length,
                      ),
                    ),
                  ],
                ),
              ),

              // Glass Composer
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4))),
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
                    Expanded(
                      child: GlassContainer(
                        color: Colors.white.withValues(alpha: 0.6),
                        blur: 16,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                          decoration: InputDecoration(
                            hintText: _editingCommentId != null
                                ? 'sc_cmt_edit_hint'.tr
                                : 'sc_cmt_add_hint'.tr,
                            border: InputBorder.none,
                            hintStyle: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sendingComment
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : GlassIconButton(
                            icon: Icons.send_rounded,
                            onPressed: _submitComment,
                            color: AppColors.brand,
                            iconColor: Colors.white,
                            size: 44,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
