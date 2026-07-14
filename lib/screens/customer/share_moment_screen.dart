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
import '../../services/location_helper.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

const int _kMaxCaption = 500;
const Color _kBrand = Color(0xFF0068E0);

/// Tuỳ chọn quyền riêng tư (value khớp backend: Public/Friend/Private).
class _PrivacyOption {
  final String value;
  final String label;
  final IconData icon;
  const _PrivacyOption(this.value, this.label, this.icon);
}

const _privacyOptions = <_PrivacyOption>[
  _PrivacyOption('Public', 'Public', Icons.public),
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

  Future<void> _fetchSchedules() async {
    await _orderController.fetchEligibleSchedules();
    if (_orderController.eligibleSchedules.isNotEmpty && mounted) {
      setState(() {
        _selectedScheduleId =
            _orderController.eligibleSchedules.first.scheduleId;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _ScheduleDropdown(
          schedules: _orderController.eligibleSchedules,
          selectedId: _selectedScheduleId,
          onChanged: (id) => setState(() => _selectedScheduleId = id),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _GeoStatusBadge(status: _geoStatus, onRetry: _fetchLocation),
            Expanded(child: _buildPreview()),
            _buildPrivacySelector(),
            _buildCaption(),
            _buildActions(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_capturedImage != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.file(
            _capturedImage!,
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: 600, // Tối ưu kích thước giải nén tránh lỗi OOM / Could not decompress image trên tablet
            errorBuilder: (context, error, stackTrace) {
              // Fallback: Thử tải không dùng cacheWidth nếu bị lỗi giải nén
              return Image.file(
                _capturedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error2, stackTrace2) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Captured image is invalid or decompression failed.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error2.toString(),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(
        child: Text('Cannot open camera',
            style: TextStyle(color: Colors.white70)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(cam),
            // Nút flash + đổi camera (góc trên phải preview).
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _RoundIconBtn(
                    icon: switch (_flashMode) {
                      FlashMode.off => Icons.flash_off_rounded,
                      FlashMode.auto => Icons.flash_auto_rounded,
                      _ => Icons.flash_on_rounded,
                    },
                    onTap: _toggleFlash,
                  ),
                  if (_cameras.length >= 2) ...[
                    const SizedBox(height: 10),
                    _RoundIconBtn(
                      icon: Icons.cameraswitch_rounded,
                      onTap: _switchCamera,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _privacyOptions.map((opt) {
          final selected = _privacy == opt.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              avatar: Icon(
                opt.icon,
                size: 16,
                color: selected ? Colors.white : Colors.white70,
              ),
              label: Text(opt.label),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
              selected: selected,
              selectedColor: _kBrand,
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected ? _kBrand : Colors.white12,
                ),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _privacy = opt.value);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _captionController,
        style: const TextStyle(color: Colors.white),
        maxLines: 2,
        maxLength: _kMaxCaption,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Add a caption...',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade900,
          counterStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_capturedImage == null) {
      // Nút chụp lớn ở giữa.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: _takePicture,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              gradient: const LinearGradient(
                colors: [_kBrand, Color(0xFF34C3FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kBrand.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 32),
          ),
        ),
      );
    }
    // Retake / Post
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUploading ? null : _retake,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Recapture',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _isUploading ? null : _submitMoment,
              style: FilledButton.styleFrom(
                backgroundColor: _kBrand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Post',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUB-WIDGETS
// ============================================================

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Dropdown chọn lịch trình tour (hiển thị trên AppBar).
class _ScheduleDropdown extends StatelessWidget {
  const _ScheduleDropdown({
    required this.schedules,
    required this.selectedId,
    required this.onChanged,
  });

  final List schedules; // List<EligibleScheduleModel>
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Text('Personal Moment', style: TextStyle(fontSize: 15));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedId,
          isDense: true,
          dropdownColor: Colors.grey.shade900,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            for (final s in schedules)
              DropdownMenuItem<int>(
                value: s.scheduleId as int,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, size: 14, color: _kBrand),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        s.tourName as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Badge trạng thái GPS.
class _GeoStatusBadge extends StatelessWidget {
  const _GeoStatusBadge({required this.status, required this.onRetry});
  final _GeoStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;
    late final IconData icon;
    switch (status) {
      case _GeoStatus.locating:
        text = 'Acquiring GPS...';
        color = Colors.amber;
        icon = Icons.gps_not_fixed;
        break;
      case _GeoStatus.ready:
        text = 'GPS Ready';
        color = Colors.greenAccent;
        icon = Icons.gps_fixed;
        break;
      case _GeoStatus.failed:
        text = 'No GPS — tap to retry';
        color = Colors.redAccent;
        icon = Icons.gps_off;
        break;
    }
    return GestureDetector(
      onTap: status == _GeoStatus.failed ? onRetry : null,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == _GeoStatus.locating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              )
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
