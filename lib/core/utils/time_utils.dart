class TimeUtils {
  TimeUtils._();

  /// Tolerância em minutos após o horário previsto antes de cobrar acréscimo.
  static const int toleranceMinutes = 3;

  /// Minuto exato de atraso em que se inicia a cobrança de acréscimo.
  static const int surchargeTriggerMinute = 4;

  /// Calcula o progresso do aluguel:
  /// progresso = (tempo_atual - start_time) / (planned_end_time - start_time)
  static double calculateProgress({
    required DateTime startTime,
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    final totalMilliseconds =
        plannedEndTime.difference(startTime).inMilliseconds;
    if (totalMilliseconds <= 0) {
      return 1.0;
    }
    final elapsedMilliseconds =
        currentTime.difference(startTime).inMilliseconds;
    final rawProgress = elapsedMilliseconds / totalMilliseconds;
    if (rawProgress < 0.0) return 0.0;
    return rawProgress;
  }

  /// Indica se o tempo atual já atingiu ou ultrapassou o término previsto.
  static bool isFinishedOrOverdue({
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    return !currentTime.isBefore(plannedEndTime);
  }

  /// Retorna a quantidade de minutos completos de atraso após o horário previsto.
  static int overdueMinutes({
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    if (currentTime.isBefore(plannedEndTime)) {
      return 0;
    }
    return currentTime.difference(plannedEndTime).inMinutes;
  }

  /// Verifica se o aluguel atingiu o 4º minuto de atraso (início do acréscimo).
  static bool hasSurchargeStarted({
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    return overdueMinutes(
          plannedEndTime: plannedEndTime,
          currentTime: currentTime,
        ) >=
        surchargeTriggerMinute;
  }

  /// Lógica de Acréscimo (Surcharge):
  /// - Tolerância de 3 minutos após o término.
  /// - A partir do 4º minuto de atraso (tempo_atraso >= 4), calcula-se:
  ///   R$ 1,00 + (minutos_completos_adicionais * 1,00).
  static double calculateSurcharge({
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    final delayMins = overdueMinutes(
      plannedEndTime: plannedEndTime,
      currentTime: currentTime,
    );
    if (delayMins < surchargeTriggerMinute) {
      return 0.0;
    }
    final additionalFullMinutes = delayMins - surchargeTriggerMinute;
    return 1.00 + (additionalFullMinutes * 1.00);
  }

  /// Formata uma duração em MM:SS ou HH:MM:SS amigável para o cronômetro.
  static String formatDurationClock(Duration duration) {
    final absDuration = duration.abs();
    final hours = absDuration.inHours;
    final minutes = absDuration.inMinutes.remainder(60);
    final seconds = absDuration.inSeconds.remainder(60);

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hourStr = hours.toString().padLeft(2, '0');
      return '$hourStr:$minStr:$secStr';
    }
    return '$minStr:$secStr';
  }

  /// Retorna descrição amigável do tempo restante ou do atraso.
  static String statusTimeLabel({
    required DateTime plannedEndTime,
    required DateTime currentTime,
  }) {
    final diff = plannedEndTime.difference(currentTime);
    if (diff.inSeconds > 0) {
      return 'Restam ${formatDurationClock(diff)}';
    } else {
      final overdue = currentTime.difference(plannedEndTime);
      return 'Expirado há ${formatDurationClock(overdue)}';
    }
  }

  /// Retorna a faixa horária no formato "HH-HH" (ex: "18-19", "19-20") para estatísticas.
  static String hourlySlotKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final startHour = local.hour;
    final endHour = (startHour + 1) % 24;
    final startStr = startHour.toString().padLeft(2, '0');
    final endStr = endHour.toString().padLeft(2, '0');
    return '$startStr-$endStr';
  }

  /// Avalia expressões aritméticas de minutos com suporte a soma e subtração.
  /// Exemplos:
  /// - "10" -> 10
  /// - "-10" -> -10
  /// - "10+20+5" -> 35
  /// - "30-10+5" -> 25
  /// - "-15+5" -> -10
  /// Retorna null se a expressão for inválida ou vazia.
  static int? evaluateMinutesExpression(String input) {
    final sanitized = input.replaceAll(' ', '').trim();
    if (sanitized.isEmpty) return null;

    final regex = RegExp(r'^([+-]?\d+)([+-]\d+)*$');
    if (!regex.hasMatch(sanitized)) return null;

    int total = 0;
    final tokenMatches = RegExp(r'[+-]?\d+').allMatches(sanitized);
    for (final match in tokenMatches) {
      final token = match.group(0);
      if (token == null) continue;
      final value = int.tryParse(token);
      if (value == null) return null;
      total += value;
    }
    return total;
  }
}
