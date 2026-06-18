import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import 'package:stayhub_mobile/models/staff_ticket_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

class StaffTicketsTab extends GetView<StaffController> {
  const StaffTicketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Vé của lịch trình')),
      body: Column(
        children: [
          // ── Banner chưa chọn lịch ──────────────────────────
          Obx(() {
            if (controller.selectedScheduleId.value == null) {
              return const _NoScheduleBanner();
            }
            return const SizedBox.shrink();
          }),

          // ── Filter bar ─────────────────────────────────────
          _TicketFilterBar(controller: controller),

          // ── Content ────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (controller.isLoadingTickets.value &&
                  controller.tickets.isEmpty) {
                return const LoadingWidget();
              }
              if (controller.tickets.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'Chưa có vé',
                        subtitle:
                        'Chọn lịch trình ở tab Lịch để xem danh sách vé',
                      ),
                    ],
                  ),
                );
              }

              final total = controller.tickets.length;
              final checkedIn =
                  controller.tickets.where((t) => t.isCheckedIn).length;

              return Column(
                children: [
                  _SummaryBar(total: total, checkedIn: checkedIn),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32)
                            .copyWith(
                          bottom: ShellLayout.bottomInset(context),
                        ),
                        itemCount: controller.tickets.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _TicketCard(ticket: controller.tickets[index]),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final scheduleId = controller.selectedScheduleId.value;
    if (scheduleId != null) await controller.fetchTickets(scheduleId);
  }
}

// ── No-schedule banner ────────────────────────────────────────────────────────

class _NoScheduleBanner extends StatelessWidget {
  const _NoScheduleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFAEEDA),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFF854F0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hãy chọn một lịch trình ở tab Lịch để xem vé',
              style: AppTextStyles.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF633806)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _TicketFilterBar extends StatefulWidget {
  const _TicketFilterBar({required this.controller});
  final StaffController controller;

  @override
  State<_TicketFilterBar> createState() => _TicketFilterBarState();
}

class _TicketFilterBarState extends State<_TicketFilterBar> {
  final _searchCtrl = TextEditingController();
  String? _selectedStatus;

  static const _statusOptions = <String?, String>{
    null: 'Tất cả',
    'Pending': 'Chưa check-in',
    'CheckedIn': 'Đã check-in',
    'Absent': 'Vắng mặt',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    widget.controller.applyTicketFilters(
      attendeeName: _searchCtrl.text,
      checkInStatus: _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _apply(),
            onChanged: (v) {
              if (v.isEmpty) _apply();
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hành khách...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  _apply();
                  setState(() {});
                },
              )
                  : null,
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Status chips
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statusOptions.entries.map((e) {
                final selected = _selectedStatus == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedStatus = e.key);
                      _apply();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.brand
                            : AppColors.surfaceGrouped,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? AppColors.brand
                              : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: AppTextStyles.textTheme.labelSmall?.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.checkedIn});
  final int total;
  final int checkedIn;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : checkedIn / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.confirmation_number_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(
            'Đã check-in',
            style: AppTextStyles.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            '$checkedIn / $total vé',
            style: AppTextStyles.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 1.0 ? Colors.green : AppColors.brand,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(progress * 100).round()}%',
            style: AppTextStyles.textTheme.labelSmall?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ticket card ───────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final StaffTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(ticket.checkInStatus);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon box
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusStyle.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusStyle.icon,
                      size: 22, color: statusStyle.iconColor),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status pill
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.attendeeName,
                              style: AppTextStyles.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: statusStyle.label,
                            color: statusStyle.pillColor,
                            bgColor: statusStyle.pillBg,
                          ),
                        ],
                      ),
                      // Ticket type
                      if (ticket.ticketTypeName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.local_activity_outlined,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              ticket.ticketTypeName!,
                              style: AppTextStyles.textTheme.labelSmall
                                  ?.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info grid ────────────────────────────────────────
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _buildInfoGrid(),
          ),

          // ── QR code ──────────────────────────────────────────
          if (ticket.qrCode != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border:
                  Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.qrCode!,
                        style: AppTextStyles.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    final cells = <_InfoCellData>[];

    cells.add(_InfoCellData(
        icon: Icons.badge_outlined, label: 'CCCD', value: ticket.idCard));

    if (ticket.dateOfBirth != null) {
      cells.add(_InfoCellData(
        icon: Icons.cake_outlined,
        label: 'Ngày sinh',
        value: DateFormat('dd/MM/yyyy').format(ticket.dateOfBirth!),
      ));
    }

    if (ticket.gender != null) {
      cells.add(_InfoCellData(
          icon: Icons.person_outlined,
          label: 'Giới tính',
          value: ticket.gender!));
    }

    if (ticket.nationality != null) {
      cells.add(_InfoCellData(
          icon: Icons.flag_outlined,
          label: 'Quốc tịch',
          value: ticket.nationality!));
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final left = cells[i];
      final right = i + 1 < cells.length ? cells[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: _InfoCell(data: left)),
            if (right != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _InfoCell(data: right)),
            ] else
              const Expanded(child: SizedBox()),
          ],
        ),
      ));
    }

    return Column(children: rows);
  }

  _TicketStatusStyle _statusStyle(String? status) {
    switch (status?.toLowerCase()) {
      case 'checkedin':
      case 'checked_in':
        return _TicketStatusStyle(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.brand,
          iconBg: AppColors.brandLight,
          label: 'Đã check-in',
          pillColor: const Color(0xFF0C447C),
          pillBg: const Color(0xFFE6F1FB),
        );
      case 'absent':
        return _TicketStatusStyle(
          icon: Icons.person_off_rounded,
          iconColor: const Color(0xFFA32D2D),
          iconBg: const Color(0xFFFCEBEB),
          label: 'Vắng mặt',
          pillColor: const Color(0xFF791F1F),
          pillBg: const Color(0xFFFCEBEB),
        );
      default:
        return _TicketStatusStyle(
          icon: Icons.confirmation_number_outlined,
          iconColor: AppColors.textSecondary,
          iconBg: AppColors.surfaceGrouped,
          label: 'Chưa check-in',
          pillColor: const Color(0xFF5F5E5A),
          pillBg: const Color(0xFFF1EFE8),
        );
    }
  }
}

class _TicketStatusStyle {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Color pillColor;
  final Color pillBg;

  const _TicketStatusStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.pillColor,
    required this.pillBg,
  });
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.bgColor,
  });
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Info cell ─────────────────────────────────────────────────────────────────

class _InfoCellData {
  const _InfoCellData(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.data});
  final _InfoCellData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(data.icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              data.label,
              style: AppTextStyles.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          data.value,
          style: AppTextStyles.textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}