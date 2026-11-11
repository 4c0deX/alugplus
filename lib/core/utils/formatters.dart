import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _timeWithSecondsFormat = DateFormat('HH:mm:ss');
  static final DateFormat _dateFormatBr = DateFormat('dd/MM/yyyy');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Formata valor numérico para moeda brasileira (ex: R$ 15,00)
  static String currency(double value) {
    return _currencyFormat.format(value);
  }

  /// Converte texto digitado pelo usuário para double (suporta vírgula ou ponto)
  static double parseCurrency(String input, {double fallback = 0.0}) {
    final cleaned = input
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? fallback;
  }

  /// Formata DateTime para HH:mm
  static String timeShort(DateTime dateTime) {
    return _timeFormat.format(dateTime.toLocal());
  }

  /// Formata DateTime para HH:mm:ss
  static String timeFull(DateTime dateTime) {
    return _timeWithSecondsFormat.format(dateTime.toLocal());
  }

  /// Formata DateTime para dd/MM/yyyy
  static String dateBr(DateTime dateTime) {
    return _dateFormatBr.format(dateTime.toLocal());
  }

  /// Formata DateTime para YYYY-MM-DD (chave de agrupamento SQLite)
  static String sqlDate(DateTime dateTime) {
    return _isoDateFormat.format(dateTime.toLocal());
  }

  /// Formata string YYYY-MM-DD para dd/MM/yyyy
  static String sqlDateToBr(String sqlDateStr) {
    final parsed = DateTime.tryParse(sqlDateStr);
    if (parsed == null) return sqlDateStr;
    return _dateFormatBr.format(parsed);
  }
}
