import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/feature_controllers.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';

class ShareMomentScreen extends StatefulWidget {
  const ShareMomentScreen({super.key});

  @override
  State<ShareMomentScreen> createState() => _ShareMomentScreenState();
}

class _ShareMomentScreenState extends State<ShareMomentScreen> {
  final _captionController = TextEditingController();
  final _social = Get.find<SocialController>();
  final _order = Get.find<OrderController>();
  final _picker = ImagePicker();

  File? _image;
  int? _scheduleId;
  var _submitting = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _order.fetchEligibleSchedules().then((_) {
      if (_order.eligibleSchedules.isNotEmpty) {
        setState(() {
          _scheduleId = _order.eligibleSchedules.first.scheduleId;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    });
    final arg = Get.arguments;
    if (arg is int) _scheduleId = arg;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_image == null || _scheduleId == null) {
      Get.snackbar('', 'Chọn ảnh và lịch trình tour');
      return;
    }
    setState(() => _submitting = true);
    final ok = await _social.shareMoment(
      scheduleId: _scheduleId!,
      imagePath: _image!.path,
      caption: _captionController.text.trim(),
    );
    setState(() => _submitting = false);
    if (ok && mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Chia sẻ Moment',
      body: _order.eligibleSchedules.isEmpty && !_loading
          ? const Center(
              child: Text('Bạn cần có tour đang/sắp diễn ra để chia sẻ moment'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(() {
                    if (_order.eligibleSchedules.isEmpty) {
                      return const LoadingWidget();
                    }
                    return DropdownButtonFormField<int>(
                      value: _scheduleId,
                      decoration: const InputDecoration(
                        labelText: 'Lịch trình tour',
                        border: OutlineInputBorder(),
                      ),
                      items: _order.eligibleSchedules.map((s) {
                        return DropdownMenuItem(
                          value: s.scheduleId,
                          child: Text('${s.tourName} (${s.statusContext})'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _scheduleId = v),
                    );
                  }),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 48),
                                Text('Chọn ảnh *'),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _captionController,
                    label: 'Caption',
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Đăng Moment',
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
