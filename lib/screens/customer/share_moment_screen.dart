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
import 'package:stayhub_mobile/theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

const int _kMaxCaption = 500;
const Color _kAccentCyan = Color(0xFF00E5FF);

/// Quyền riêng tư (Public/Friend/Private).
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
  final FlashMode _flashMode = FlashMode.off;

  File? _capturedImage;
  int? _selectedScheduleId;
  String _privacy = 'Public';

  double? _lat;
  double? _lng;

  bool _isInitializing = true;
  bool _isUploading = false;
  bool _isCameraInitializedFirstTime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _fetchSchedules();
    _fetchLocation();
  }

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
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {}
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
      if (!_isCameraInitializedFirstTime) {
        _cameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (_cameraIndex < 0) _cameraIndex = 0;
        _isCameraInitializedFirstTime = true;
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

  Future<void> _takePicture() async {
    if (_ongoingSchedules.isEmpty) {
      SnackbarHelper.error(
          'Bạn chỉ có thể chụp Moment cho Tour đã hoặc đang diễn ra.');
      return;
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      HapticFeedback.mediumImpact();
      final xFile = await cam.takePicture();
      final file = File(xFile.path);

      if (mounted) setState(() => _capturedImage = file);
    } catch (_) {
      SnackbarHelper.error('Cannot capture photo');
    }
  }

  void _retake() => setState(() => _capturedImage = null);

  Future<void> _submitMoment() async {
    if (_ongoingSchedules.isEmpty) {
      SnackbarHelper.error(
          'Bạn chỉ có thể đăng Moment cho Tour đã hoặc đang diễn ra.');
      return;
    }
    if (_capturedImage == null) return;

    if (!await _capturedImage!.exists() ||
        await _capturedImage!.length() == 0) {
      SnackbarHelper.error(
          'Captured image is invalid or empty. Please recapture.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (_lat == null || _lng == null) {
        await _fetchLocation();
        if (_lat == null || _lng == null) {
          SnackbarHelper.error(
            'Could not get GPS location - moment will not display on map',
          );
        }
      }

      final compressedFile = await ImageHelper.compressImage(_capturedImage!);

      final success = await _socialController.shareMoment(
        compressedFile.path,
        _selectedScheduleId,
        _lat ?? 0.0,
        _lng ?? 0.0,
        _captionController.text,
        _privacy,
      );

      if (mounted) {
        setState(() => _isUploading = false);
      }

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
      SnackbarHelper.error('Cannot share moment at this time: $e');
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
      backgroundColor: Colors.white,
      body: _capturedImage != null
          ? SafeArea(child: _buildReviewScreen())
          : _buildCameraScreen(schedules),
    );
  }

  // ── CAMERA SCREEN ─────────────────────────────────────────────────────────

  Widget _buildCameraScreen(List<EligibleScheduleModel> schedules) {
    return Stack(
      children: [
        // 1. Camera Preview covering the whole viewport
        Positioned.fill(
          child: _buildCameraContent(),
        ),

        // 2. Top Bar Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Invisible placeholder to keep TourPill perfectly centered
                const SizedBox(width: 36),

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
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Bottom controls floating overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              top: 32,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tour dropdown & minimalist Privacy Selector Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HistoryPill(
                      schedules: schedules,
                      selectedId: _selectedScheduleId,
                      onChanged: (id) => setState(() {
                        _selectedScheduleId = id;
                        if (id == 0 && _privacy == 'Tour') _privacy = 'Public';
                      }),
                    ),
                    const SizedBox(width: 12),
                    _PrivacyPill(
                      currentPrivacy: _privacy,
                      hasTour: (_selectedScheduleId ?? 0) != 0,
                      onChanged: (val) => setState(() {
                        _privacy = val;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Shutter Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spacer to balance flip button on right
                      const SizedBox(width: 44),

                      // Glowing Shutter button
                      _LocketShutterButton(onTap: _takePicture),

                      // Switch camera button
                      _BottomIconBtn(
                        icon: Icons.flip_camera_ios_outlined,
                        onTap: _cameras.length >= 2 ? _switchCamera : () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraContent() {
    if (_isInitializing) {
      return Container(
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return Container(
        color: AppColors.textPrimary,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 48),
              SizedBox(height: 12),
              Text('Camera unavailable',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    var cameraRatio = cam.value.aspectRatio;
    
    // Ensure camera ratio is in portrait (width < height)
    if (cameraRatio > 1) {
      cameraRatio = 1 / cameraRatio;
    }

    final deviceRatio = size.width / size.height;
    
    // Calculate scale to cover the screen
    double scale = 1.0;
    if (deviceRatio < cameraRatio) {
      scale = cameraRatio / deviceRatio;
    } else {
      scale = deviceRatio / cameraRatio;
    }

    return Transform.scale(
      scale: scale,
      child: Center(
        child: AspectRatio(
          aspectRatio: cameraRatio,
          child: CameraPreview(cam),
        ),
      ),
    );
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.black, size: 20),
                ),
              ),
              const Spacer(),
              const Text(
                'Preview',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 17),
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
                        child: Icon(Icons.broken_image_rounded,
                            color: Colors.white30, size: 48),
                      ),
                    ),
                  ),

                  // Caption overlay at bottom of image
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ],
                        ),
                        maxLines: 2,
                        maxLength: _kMaxCaption,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: Get.locale?.languageCode == 'vi'
                              ? 'Thêm dòng trạng thái...'
                              : 'Add a caption...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4)
                            ],
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          counterStyle:
                              const TextStyle(color: Colors.white54, fontSize: 11),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          fillColor: Colors.transparent,
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
                .where((opt) =>
                    opt.value != 'Tour' || (_selectedScheduleId ?? 0) != 0)
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      color: sel ? AppColors.brand : Colors.grey.shade100,
                      border: Border.all(
                        color: sel ? AppColors.brand : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon,
                            size: 13,
                            color: sel ? Colors.white : Colors.black54),
                        const SizedBox(width: 5),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : Colors.black54,
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
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Send Moment',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.3),
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

/// Large Locket-style shutter: white fill + cyan glowing ring border.
class _LocketShutterButton extends StatelessWidget {
  const _LocketShutterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brand, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.35),
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

/// Flip camera icon button at the bottom row.
class _BottomIconBtn extends StatelessWidget {
  const _BottomIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Tour pill in the top-centre.
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
      return tourCount > 0
          ? '$tourCount Tour${tourCount > 1 ? 's' : ''}'
          : 'Personal';
    }
    return found.first.tourName;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: AppColors.textPrimary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
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
                color:
                    s.scheduleId == selectedId ? AppColors.brand : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.tourName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: s.scheduleId == selectedId
                        ? AppColors.brand
                        : Colors.white,
                    fontWeight: s.scheduleId == selectedId
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              if (s.scheduleId == selectedId)
                const Icon(Icons.check_rounded, size: 14, color: AppColors.brand),
            ],
          ),
          onTap: () => onChanged(s.scheduleId),
        );
      }).toList(),
    );
  }
}

/// "History" pill below the shutter row (shows tour name as a dropdown).
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
    final label = schedules
            .where((s) => s.scheduleId == selectedId)
            .firstOrNull
            ?.tourName ??
        'History';

    return PopupMenuButton<int>(
      color: AppColors.textPrimary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      offset: const Offset(0, -120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tour_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 16),
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
                color:
                    s.scheduleId == selectedId ? _kAccentCyan : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.tourName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: s.scheduleId == selectedId
                        ? _kAccentCyan
                        : Colors.white,
                    fontWeight: s.scheduleId == selectedId
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              if (s.scheduleId == selectedId)
                const Icon(Icons.check_rounded, size: 14, color: _kAccentCyan),
            ],
          ),
          onTap: () => onChanged(s.scheduleId),
        );
      }).toList(),
    );
  }
}

/// Minimalist Privacy selector next to the Tour selection pill.
class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill({
    required this.currentPrivacy,
    required this.hasTour,
    required this.onChanged,
  });

  final String currentPrivacy;
  final bool hasTour;
  final ValueChanged<String> onChanged;

  IconData get _icon {
    final found =
        _privacyOptions.where((opt) => opt.value == currentPrivacy).firstOrNull;
    return found?.icon ?? Icons.public;
  }

  String get _label {
    final found =
        _privacyOptions.where((opt) => opt.value == currentPrivacy).firstOrNull;
    return found?.label ?? 'Public';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.textPrimary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      offset: const Offset(0, -120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              _label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => _privacyOptions
          .where((opt) => opt.value != 'Tour' || hasTour)
          .map((opt) {
        final isSelected = opt.value == currentPrivacy;
        return PopupMenuItem<String>(
          value: opt.value,
          child: Row(
            children: [
              Icon(
                opt.icon,
                size: 16,
                color: isSelected ? _kAccentCyan : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                opt.label,
                style: TextStyle(
                  color: isSelected ? _kAccentCyan : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (isSelected) const Spacer(),
              if (isSelected)
                const Icon(Icons.check_rounded, size: 14, color: _kAccentCyan),
            ],
          ),
          onTap: () => onChanged(opt.value),
        );
      }).toList(),
    );
  }
}
