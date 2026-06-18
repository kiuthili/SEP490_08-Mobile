import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';

class StaffCustomersTab extends GetView<StaffController> {
  const StaffCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Khách hàng & Vị trí'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Khách tour'),
              Tab(text: 'Vị trí live'),
              Tab(text: 'Bản đồ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CustomersTab(controller: controller),
            _LiveLocationsTab(controller: controller),
            _MapTab(controller: controller),
          ],
        ),
      ),
    );
  }
}

// ── Customers tab ─────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  const _CustomersTab({required this.controller});
  final StaffController controller;

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              widget.controller.applyCustomerFilter(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hành khách...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  widget.controller.applyCustomerFilter('');
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
        ),

        // ── List ──────────────────────────────────────────────
        Expanded(
          child: Obx(() {
            if (widget.controller.customers.isEmpty) {
              return const EmptyStateWidget(
                title: 'Chưa có khách',
                subtitle: 'Chọn lịch trình ở tab Lịch trình',
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: widget.controller.customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _CustomerCard(
                  customer: widget.controller.customers[index],
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    final initial = (customer.attendeeName as String).trim().isNotEmpty
        ? (customer.attendeeName as String).trim()[0].toUpperCase()
        : '?';

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
          // ── Header: avatar + name + ticket + status ─────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brandLight,
                  child: Text(
                    initial,
                    style: AppTextStyles.textTheme.titleMedium?.copyWith(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + ticket pill
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.displayName as String,
                        style: AppTextStyles.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _TicketPill(ticketId: customer.ticketId as int),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info grid ────────────────────────────────────────
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: _InfoGrid(customer: customer),
          ),
        ],
      ),
    );
  }
}

// ── Info grid (2-col) ─────────────────────────────────────────────────────────

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.customer});
  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    final cells = <_InfoCellData>[];

    cells.add(_InfoCellData(
      icon: Icons.badge_rounded,
      label: 'CCCD / Hộ chiếu',
      value: (customer.idCard as String?) ?? '—',
      fullWidth: true,
    ));

    if ((customer.phoneNumber as String?)?.isNotEmpty ?? false) {
      cells.add(_InfoCellData(
        icon: Icons.phone_rounded,
        label: 'SĐT',
        value: customer.phoneNumber as String,
      ));
    }

    if ((customer.dateOfBirth as String?)?.isNotEmpty ?? false) {
      cells.add(_InfoCellData(
        icon: Icons.cake_rounded,
        label: 'Ngày sinh',
        value: customer.dateOfBirth as String,
      ));
    }

    final genderLabel = customer.genderLabel as String? ?? '';
    if (genderLabel.isNotEmpty) {
      cells.add(_InfoCellData(
        icon: Icons.person_rounded,
        label: 'Giới tính',
        value: genderLabel,
      ));
    }

    if ((customer.nationality as String?)?.isNotEmpty ?? false) {
      cells.add(_InfoCellData(
        icon: Icons.flag_rounded,
        label: 'Quốc tịch',
        value: customer.nationality as String,
        fullWidth: true,
      ));
    }

    // Build 2-column grid manually
    final rows = <Widget>[];
    int i = 0;
    while (i < cells.length) {
      final cell = cells[i];
      if (cell.fullWidth) {
        rows.add(_InfoCell(data: cell));
        i++;
      } else if (i + 1 < cells.length && !cells[i + 1].fullWidth) {
        rows.add(Row(
          children: [
            Expanded(child: _InfoCell(data: cells[i])),
            const SizedBox(width: 12),
            Expanded(child: _InfoCell(data: cells[i + 1])),
          ],
        ));
        i += 2;
      } else {
        rows.add(Row(
          children: [
            Expanded(child: _InfoCell(data: cell)),
            const Expanded(child: SizedBox()),
          ],
        ));
        i++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: r,
      ))
          .toList(),
    );
  }
}

class _InfoCellData {
  const _InfoCellData({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;
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
            Icon(data.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              data.label,
              style: AppTextStyles.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
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

// ── Ticket pill ───────────────────────────────────────────────────────────────

class _TicketPill extends StatelessWidget {
  const _TicketPill({required this.ticketId});
  final int ticketId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_number_rounded,
              size: 12, color: AppColors.brand),
          const SizedBox(width: 4),
          Text(
            'Vé #$ticketId',
            style: AppTextStyles.textTheme.labelSmall?.copyWith(
              color: AppColors.brandDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live locations tab ────────────────────────────────────────────────────────

class _LiveLocationsTab extends StatelessWidget {
  const _LiveLocationsTab({required this.controller});
  final StaffController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.liveLocations.isEmpty) {
        return const EmptyStateWidget(
          title: 'Chưa có vị trí',
          subtitle: 'Khách chưa chia sẻ vị trí',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32).copyWith(
          bottom: ShellLayout.bottomInset(context),
        ),
        itemCount: controller.liveLocations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final loc = controller.liveLocations[index];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.fullName ?? 'User #${loc.userId}',
                        style: AppTextStyles.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.my_location_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${loc.latitude.toStringAsFixed(5)}, '
                                '${loc.longitude.toStringAsFixed(5)}',
                            style: AppTextStyles.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (loc.updatedAt != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Cập nhật ${_timeAgo(loc.updatedAt!)}',
                              style: AppTextStyles.textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}

// ── Map tab ───────────────────────────────────────────────────────────────────

class _MapTab extends StatelessWidget {
  const _MapTab({required this.controller});
  final StaffController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.liveLocations.isEmpty) {
        return const EmptyStateWidget(
          title: 'Chưa có dữ liệu vị trí',
          subtitle: 'Khách chưa chia sẻ vị trí',
        );
      }
      final locs = controller.liveLocations;
      final center = LatLng(locs.first.latitude, locs.first.longitude);
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 1 || constraints.maxWidth < 1) {
            return const SizedBox.shrink();
          }
          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.stayhub.mobile',
              ),
              MarkerLayer(
                markers: locs.map((loc) {
                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 120,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border:
                            Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: Text(
                            loc.fullName ?? '#${loc.userId}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 28),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      );
    });
  }
}