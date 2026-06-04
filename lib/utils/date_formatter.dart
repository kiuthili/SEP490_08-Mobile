import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String display(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDate(DateTime? date) => display(date);
}
