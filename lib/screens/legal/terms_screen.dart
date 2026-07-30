import 'package:flutter/material.dart';
import '../../legal/terms_content.dart';
import '../../routes/app_routes.dart';
import 'legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'Điều khoản dịch vụ',
      lastUpdated: termsSectionsViLastUpdated,
      sections: termsSectionsVi,
      settingKey: 'TermsAndConditions',
      relatedDocuments: const [
        {
          'label': 'Xem Chính sách quyền riêng tư',
          'route': AppRoutes.privacy,
        },
        {
          'label': 'Xem Quy định đặt tour & Hủy vé',
          'route': AppRoutes.bookingTerms,
        },
      ],
    );
  }
}
