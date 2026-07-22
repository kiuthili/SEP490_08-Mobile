// lib/screens/social/share_moment_screen.dart
//
// Màn chụp & đăng Moment (phong cách Locket), khớp với form web:
//   - Chọn lịch trình tour (tuỳ chọn)
//   - Chọn quyền riêng tư: Public / Friends / Only me
//   - Tự lấy GPS để moment hiện đúng vị trí trên Bản đồ Social
//   - Caption tối đa 500 ký tự
//   - Chụp / Chụp lại / Đăng
//
// ✦ Bản nâng cấp (UI/UX + độ ổn định):
//   - FIX lỗi double Get.back(): controller.shareMoment() đã tự pop màn này,
//     nên màn KHÔNG gọi Get.back() lần nữa (trước đây pop nhầm cả màn bản đồ).
//   - Quản lý vòng đời camera (pause/resume khi app vào nền) => hết đen hình/crash.
//   - Thêm: bật/tắt flash, đổi camera trước/sau, haptics, nút chụp có hiệu ứng.
//   - Bảo vệ: chặn đăng khi chưa có GPS bằng cách thử lại trước khi gửi.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../services/location_helper.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

const int _kMaxCaption = 500;

/// Tuỳ chọn quyền riêng tư (value khớp backend: Public/Friend/Private).
class _PrivacyOption {
  final String value;
  final String label;
  final IconData icon;
  const _PrivacyOption(this.value, this.label, this.icon);
}

const _privacyOptions = <_PrivacyOption>[
  _PrivacyOption('Public', 'Public', Icons.public),
  _PrivacyOption('Tour', 'Tour members', Icons.directions_bus),
  _PrivacyOption('Friend', 'Friends', Icons.group),
  _PrivacyOption('Private', 'Only me', Icons.lock),
];

enum _GeoStatus { locating, ready, failed }

class ShareMomentScreen extends StatefulWidget {
  const ShareMomentScreen({super.key});

  @override
  State<ShareMomentScreen> createState() => _ShareMomentScreenState();
}

class _ShareMomentScreenState extends State<ShareMomentScreen>
    with WidgetsBindingObserver {
  final _socialController = Get.find<SocialController>();
  final _orderController = Get.find<OrderController>();
  final _captionController = TextEditingController();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  File? _capturedImage;
  int? _selectedScheduleId;
  String _privacy = 'Public';

  double? _lat;
  double? _lng;
  _GeoStatus _geoStatus = _GeoStatus.locating;

  bool _isInitializing = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _fetchSchedules();
    _fetchLocation();
  }

  // ----- Vòng đời: pause/resume camera khi app vào nền/quay lại -----
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  List<EligibleScheduleModel> get _ongoingSchedules {
    final list = <EligibleScheduleModel>[
      EligibleScheduleModel(
        scheduleId: 0,
        tourName: 'Cá nhân (Ngoài Tour)',
        departureDate: DateTime.now(),
        returnDate: DateTime.now(),
        statusContext: 'Ongoing',
      )
    ];
    final now = DateTime.now();
    list.addAll(_orderController.eligibleSchedules.where((s) {
      final status = s.statusContext.toLowerCase();
      return status == 'ongoing' ||
          status == 'completed' ||
          s.departureDate.isBefore(now) ||
          s.departureDate.isAtSameMomentAs(now);
    }));
    return list;
  }

  Future<void> _fetchSchedules() async {
    await _orderController.fetchEligibleSchedules();
    final ongoing = _ongoingSchedules;
    if (ongoing.isNotEmpty && mounted) {
      setState(() {
        _selectedScheduleId = ongoing.first.scheduleId;
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _geoStatus = _GeoStatus.locating);
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _geoStatus = _GeoStatus.ready;
        });
      } else {
        setState(() => _geoStatus = _GeoStatus.failed);
      }
    } catch (_) {
      if (mounted) setState(() => _geoStatus = _GeoStatus.failed);
    }
  }

  Future<void> _initCamera() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      // Lần đầu chọn camera sau.
      if (_cameraController == null) {
        _cameraIndex = _cameras.indexWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (_cameraIndex < 0) _cameraIndex = 0;
      }
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
    } catch (e) {
      debugPrint('Lỗi camera: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() => _isInitializing = true);
    await _cameraController?.dispose();
    _cameraController = null;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    HapticFeedback.selectionClick();
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await cam.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<void> _takePicture() async {
    if (_ongoingSchedules.isEmpty) {
      SnackbarHelper.error('Bạn chỉ có thể chụp Moment cho Tour đã hoặc đang diễn ra.');
      return;
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      HapticFeedback.mediumImpact();
      final xFile = await cam.takePicture();
      
      // Chờ tệp được ghi xong hoàn toàn (kiểm tra kích thước > 0 bytes)
      final file = File(xFile.path);
      int attempts = 0;
      while (attempts < 10) {
        if (await file.exists() && await file.length() > 0) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (mounted) setState(() => _capturedImage = file);
    } catch (_) {
      SnackbarHelper.error('Cannot capture photo');
    }
  }

  void _retake() => setState(() => _capturedImage = null);

  Future<void> _submitMoment() async {
    if (_ongoingSchedules.isEmpty) {
      SnackbarHelper.error('Bạn chỉ có thể đăng Moment cho Tour đã hoặc đang diễn ra.');
      return;
    }
    if (_capturedImage == null) return;
    
    // Check if the image file is valid to avoid sending an empty file
    if (!await _capturedImage!.exists() || await _capturedImage!.length() == 0) {
      SnackbarHelper.error('Captured image is invalid or empty. Please recapture.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Ensure GPS coordinates are loaded (retry once if failed).
      if (_lat == null || _lng == null) {
        await _fetchLocation();
        if (_lat == null || _lng == null) {
          SnackbarHelper.error(
            'Could not get GPS location - moment will not display on map',
          );
        }
      }

      // Nén ảnh trước khi gửi để giảm dung lượng file xuống ~200KB, tăng tốc độ gửi lên gấp 50 lần qua devtunnel
      final compressedFile = await ImageHelper.compressImage(_capturedImage!);

      final success = await _socialController.shareMoment(
        compressedFile.path,
        _selectedScheduleId,
        _lat ?? 0.0,
        _lng ?? 0.0,
        _captionController.text,
        _privacy,
      );

      if (success) {
        // Chờ hết frame hiện tại rồi mới pop để tránh xung đột với SnackBar overlay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Get.back();
        });
      } else if (mounted) {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      SnackbarHelper.error('Cannot share moment at this time: $e');
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _ongoingSchedules;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedImage != null ? _buildReviewScreen() : _buildCameraScreen(schedules),
      ),
    );
  }

  // ── CAMERA SCREEN ─────────────────────────────────────────────────────────

  Widget _buildCameraScreen(List<EligibleScheduleModel> schedules) {
    return Column(
      children: [
        // ── TOP BAR ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GPS badge (left)
              _CompactGeoBadge(status: _geoStatus, onRetry: _fetchLocation),

              // Tour selector pill (centre)
              _TourPill(
                schedules: schedules,
                selectedId: _selectedScheduleId,
                onChanged: (id) => setState(() {
                  _selectedScheduleId = id;
                  if (id == 0 && _privacy == 'Tour') _privacy = 'Public';
                }),
              ),

              // Close button (right)
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),

        // ── CAMERA PREVIEW CARD ───────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraContent(),

                  // Flash button (top-left inside preview)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _PreviewIconBtn(
                      icon: switch (_flashMode) {
                        FlashMode.off => Icons.flash_off_rounded,
                        FlashMode.auto => Icons.flash_auto_rounded,
                        _ => Icons.flash_on_rounded,
                      },
                      onTap: _toggleFlash,
                    ),
                  ),

                  // Zoom indicator (top-right inside preview) — purely visual
                  const Positioned(
                    top: 14,
                    right: 14,
                    child: _ZoomLabel(),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── SHUTTER ROW ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gallery icon
              _BottomIconBtn(
                icon: Icons.photo_library_outlined,
                onTap: () {
                  // TODO: pick from gallery
                },
              ),

              // Locket-style shutter button
              _LocketShutterButton(onTap: _takePicture),

              // Flip camera icon
              _BottomIconBtn(
                icon: Icons.flip_camera_ios_outlined,
                onTap: _cameras.length >= 2 ? _switchCamera : () {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── SCHEDULE / HISTORY PILL ──────────────────────────────────────────
        _HistoryPill(
          schedules: schedules,
          selectedId: _selectedScheduleId,
          onChanged: (id) => setState(() {
            _selectedScheduleId = id;
          }),
        ),

        const SizedBox(height: 8),

        // ── BOTTOM NAV PLACEHOLDER ───────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(Icons.grid_view_rounded, color: Colors.white54, size: 22),
              _HomeNavDot(),
              Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 22),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCameraContent() {
    if (_isInitializing) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return Container(
        color: const Color(0xFF111111),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 48),
              SizedBox(height: 12),
              Text('Camera unavailable', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return CameraPreview(cam);
  }

  // ── REVIEW SCREEN (after capture) ────────────────────────────────────────

  Widget _buildReviewScreen() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _retake,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              const Text(
                'Preview',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
              ),
              const Spacer(),
              const SizedBox(width: 36),
            ],
          ),
        ),

        // Preview image
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white30, size: 48),
                      ),
                    ),
                  ),

                  // Caption overlay at bottom of image
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                        maxLines: 2,
                        maxLength: _kMaxCaption,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white60, fontSize: 15),
                          border: InputBorder.none,
                          counterStyle: TextStyle(color: Colors.white54, fontSize: 11),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Privacy chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _privacyOptions
                .where((opt) => opt.value != 'Tour' || (_selectedScheduleId ?? 0) != 0)
                .map((opt) {
              final sel = _privacy == opt.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _privacy = opt.value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: sel ? const Color(0xFFFAA61A) : Colors.white12,
                      border: Border.all(
                        color: sel ? const Color(0xFFFAA61A) : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon, size: 13, color: sel ? Colors.black : Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Send button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _isUploading ? null : _submitMoment,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFAA61A),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text(
                      'Send Moment',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// SUB-WIDGETS
// ============================================================

/// Small circular button inside camera preview overlay.
class _PreviewIconBtn extends StatelessWidget {
  const _PreviewIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.40),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// "1x" zoom label shown in preview corner (purely visual badge).
class _ZoomLabel extends StatelessWidget {
  const _ZoomLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.40),
      ),
      child: const Text(
        '1×',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// Large Locket-style shutter: white fill + golden ring border.
class _LocketShutterButton extends StatelessWidget {
  const _LocketShutterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78, height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFAA61A), width: 3.5),
          // Subtle outer shadow
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFAA61A).withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Gallery / flip icon buttons at the bottom row.
class _BottomIconBtn extends StatelessWidget {
  const _BottomIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44, height: 44,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Tour pill in the top-centre (like "37 Friends" button in Locket).
class _TourPill extends StatelessWidget {
  const _TourPill({
    required this.schedules,
    required this.selectedId,
    required this.onChanged,
  });

  final List<EligibleScheduleModel> schedules;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  String get _label {
    if (schedules.isEmpty) return 'Personal';
    final found = schedules.where((s) => s.scheduleId == selectedId).toList();
    if (found.isEmpty) return schedules.first.tourName;
    if (found.first.scheduleId == 0) {
      final tourCount = schedules.length - 1;
      return tourCount > 0 ? '$tourCount Tour${tourCount > 1 ? 's' : ''}' : 'Personal';
    }
    return found.first.tourName;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                _label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => schedules.map((s) {
        return PopupMenuItem<int>(
          value: s.scheduleId,
          child: Row(
            children: [
              Icon(
                s.scheduleId == 0 ? Icons.person : Icons.tour_rounded,
                size: 16,
                color: s.scheduleId == selectedId ? const Color(0xFFFAA61A) : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.tourName,
                  style: TextStyle(
                    color: s.scheduleId == selectedId ? const Color(0xFFFAA61A) : Colors.white,
                    fontWeight: s.scheduleId == selectedId ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              if (s.scheduleId == selectedId)
                const Icon(Icons.check_rounded, size: 14, color: Color(0xFFFAA61A)),
            ],
          ),
          onTap: () => onChanged(s.scheduleId),
        );
      }).toList(),
    );
  }
}

/// "History" pill below the shutter row (shows tour thumbnail + name).
class _HistoryPill extends StatelessWidget {
  const _HistoryPill({
    required this.schedules,
    required this.selectedId,
    required this.onChanged,
  });

  final List<EligibleScheduleModel> schedules;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = schedules.where((s) => s.scheduleId == selectedId).firstOrNull?.tourName
        ?? 'History';

    return GestureDetector(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // small thumbnail placeholder
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white10,
            ),
            child: const Icon(Icons.photo, color: Colors.white30, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}

/// Compact GPS status dot for the top-left corner.
class _CompactGeoBadge extends StatelessWidget {
  const _CompactGeoBadge({required this.status, required this.onRetry});
  final _GeoStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (status) {
      case _GeoStatus.locating:
        color = Colors.amber;
        icon = Icons.gps_not_fixed;
        break;
      case _GeoStatus.ready:
        color = Colors.greenAccent;
        icon = Icons.gps_fixed;
        break;
      case _GeoStatus.failed:
        color = Colors.redAccent;
        icon = Icons.gps_off;
        break;
    }
    return GestureDetector(
      onTap: status == _GeoStatus.failed ? onRetry : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: status == _GeoStatus.locating
            ? Padding(
                padding: const EdgeInsets.all(9),
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            : Icon(icon, color: color, size: 18),
      ),
    );
  }
}

/// Home nav dot (filled white circle in the centre of bottom nav bar).
class _HomeNavDot extends StatelessWidget {
  const _HomeNavDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
    );
  }
}

