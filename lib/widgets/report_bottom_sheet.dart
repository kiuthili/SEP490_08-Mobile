import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feature_controllers.dart';
import '../theme/app_colors.dart';

class ReportBottomSheet {
  static void show(BuildContext context, String contentType, int targetId) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    var isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contentType == 'Moment' ? 'sc_report_moment'.tr : 'sc_report_comment'.tr,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        labelText: 'sc_report_reason'.tr,
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Spam', child: Text('sc_report_spam'.tr)),
                        DropdownMenuItem(
                            value: 'Hate Speech', // API expects Hate Speech
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
                          setSheetState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: detailsController,
                      decoration: InputDecoration(
                        labelText: 'sc_report_details'.tr,
                        hintText: 'sc_report_details_hint'.tr,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSending ? null : () => Navigator.pop(context),
                            child: Text('sc_report_cancel'.tr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSending
                                ? null
                                : () async {
                                    setSheetState(() => isSending = true);
                                    final social = Get.find<SocialController>();
                                    final ok = await social.reportContent(
                                      contentType: contentType,
                                      targetId: targetId,
                                      reason: selectedReason,
                                      details: detailsController.text
                                              .trim()
                                              .isNotEmpty
                                          ? detailsController.text.trim()
                                          : null,
                                    );
                                    setSheetState(() => isSending = false);
                                    if (ok && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: isSending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text('sc_report_submit'.tr),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
