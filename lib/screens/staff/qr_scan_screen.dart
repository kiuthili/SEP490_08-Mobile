import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/feature_controllers.dart';
import '../../widgets/app_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _staff = Get.find<StaffController>();
  var _processed = false;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Quét QR Check-in',
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) async {
                if (_processed) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final code = barcodes.first.rawValue;
                if (code == null || code.isEmpty) return;
                setState(() => _processed = true);
                final ok = await _staff.checkIn(code);
                if (mounted) {
                  if (ok) {
                    Get.back(result: code);
                  } else {
                    setState(() => _processed = false);
                  }
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Hướng camera vào mã QR trên vé khách hàng',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
