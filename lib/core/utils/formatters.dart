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

  /// Converte texto digitado pelo usuário para double (suporta vírgula, ponto e separador de milhar)
  static double parseCurrency(String input, {double fallback = 0.0}) {
    var cleaned = input.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return fallback;

    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastComma > lastDot) {
        // Formato brasileiro: "1.250,50" -> remove ponto de milhar e troca vírgula decimal
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Formato internacional: "1,250.50" -> remove vírgula de milhar
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      // Vírgula decimal sem milhar: "25,50" -> "25.50"
      cleaned = cleaned.replaceAll(',', '.');
    } else if (lastDot != -1) {
      // Múltiplos pontos sem vírgula: "1.000.000" -> "1000000"
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
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
