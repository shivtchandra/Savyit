import 'package:hugeicons/hugeicons.dart';

// lib/models/date_range_option.dart
enum DateRangeOption {
  allTime,
  today,
  yesterday,
  past2Days,
  past3Days,
  lastWeek,
  last2Weeks,
  custom,
}

extension DateRangeOptionExt on DateRangeOption {
  String get label {
    switch (this) {
      case DateRangeOption.allTime:
        return 'All Time';
      case DateRangeOption.today:
        return 'Today';
      case DateRangeOption.yesterday:
        return 'Yesterday';
      case DateRangeOption.past2Days:
        return 'Past 2 Days';
      case DateRangeOption.past3Days:
        return 'Past 3 Days';
      case DateRangeOption.lastWeek:
        return 'Last Week';
      case DateRangeOption.last2Weeks:
        return 'Last 2 Weeks';
      case DateRangeOption.custom:
        return 'Custom';
    }
  }

  dynamic get icon {
    switch (this) {
      case DateRangeOption.allTime:
        return HugeIcons.strokeRoundedCalendar03;
      case DateRangeOption.today:
        return HugeIcons.strokeRoundedSun03;
      case DateRangeOption.yesterday:
        return HugeIcons.strokeRoundedMoon02;
      case DateRangeOption.past2Days:
        return HugeIcons.strokeRoundedCalendar03;
      case DateRangeOption.past3Days:
        return HugeIcons.strokeRoundedCalendar03;
      case DateRangeOption.lastWeek:
        return HugeIcons.strokeRoundedCalendar03;
      case DateRangeOption.last2Weeks:
        return HugeIcons.strokeRoundedAnalytics01;
      case DateRangeOption.custom:
        return HugeIcons.strokeRoundedCalendarAdd01;
    }
  }

  /// Returns [from, to] DateTime range for this option.
  List<DateTime> resolve({DateTime? customFrom, DateTime? customTo}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (this) {
      case DateRangeOption.allTime:
        return [DateTime(2000, 1, 1), todayEnd];
      case DateRangeOption.today:
        return [today, todayEnd];
      case DateRangeOption.yesterday:
        final yest = today.subtract(const Duration(days: 1));
        return [yest, today.subtract(const Duration(seconds: 1))];
      case DateRangeOption.past2Days:
        return [today.subtract(const Duration(days: 2)), todayEnd];
      case DateRangeOption.past3Days:
        return [today.subtract(const Duration(days: 3)), todayEnd];
      case DateRangeOption.lastWeek:
        return [today.subtract(const Duration(days: 7)), todayEnd];
      case DateRangeOption.last2Weeks:
        return [today.subtract(const Duration(days: 14)), todayEnd];
      case DateRangeOption.custom:
        return [
          customFrom ?? today.subtract(const Duration(days: 7)),
          customTo ?? todayEnd,
        ];
    }
  }
}
