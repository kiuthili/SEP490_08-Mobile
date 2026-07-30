import 'package:flutter/material.dart';
import '../../legal/privacy_content.dart';
import '../../routes/app_routes.dart';
import 'legal_document_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'Chính sách quyền riêng tư',
      lastUpdated: privacySectionsViLastUpdated,
      sections: privacySectionsVi,
      settingKey: 'PrivacyPolicy',
      relatedDocuments: const [
        {
          'label': 'Xem Điều khoản dịch vụ',
          'route': AppRoutes.terms,
        },
        {
          'label': 'Xem Quy định đặt tour & Hủy vé',
          'route': AppRoutes.bookingTerms,
        },
      ],
    );
  }
}
