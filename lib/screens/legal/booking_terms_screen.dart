import 'package:flutter/material.dart';
import '../../legal/booking_terms_content.dart';
import '../../routes/app_routes.dart';
import 'legal_document_screen.dart';

class BookingTermsScreen extends StatelessWidget {
  const BookingTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'Quy định đặt tour & Hủy vé',
      lastUpdated: bookingTermsSectionsViLastUpdated,
      sections: bookingTermsSectionsVi,
      settingKey: 'RefundRegulations',
      relatedDocuments: const [
        {
          'label': 'Xem Điều khoản dịch vụ',
          'route': AppRoutes.terms,
        },
        {
          'label': 'Xem Chính sách quyền riêng tư',
          'route': AppRoutes.privacy,
        },
      ],
    );
  }
}
