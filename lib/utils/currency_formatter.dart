import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static NumberFormat? _fmt;

  static NumberFormat get _formatter {
    if (_fmt != null) return _fmt!;
    try {
      _fmt = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: 'VND',
        decimalDigits: 0,
      );
      _fmt!.format(0);
      return _fmt!;
    } catch (_) {
      _fmt = NumberFormat.currency(
        locale: 'en_US',
        symbol: 'VND',
        decimalDigits: 0,
      );
      return _fmt!;
    }
  }

  static String format(num amount) {
    final value = amount is int ? amount : amount.round();
    return _formatter.format(value);
  }
}
