import 'package:flutter/material.dart';

class TemporalActivityUtils {
  static bool isTonightActivity(DateTime? startDateTime) {
    if (startDateTime == null) return false;
    final now = DateTime.now();
    return DateUtils.isSameDay(startDateTime, now) && startDateTime.hour >= 18;
  }

  static bool isWeekendActivity(DateTime? startDateTime) {
    if (startDateTime == null) return false;
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSaturday,
    );
    final sunday = saturday.add(const Duration(days: 1));
    return DateUtils.isSameDay(startDateTime, saturday) ||
        DateUtils.isSameDay(startDateTime, sunday);
  }
}
