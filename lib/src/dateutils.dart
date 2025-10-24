// ============================================================================
// DateTime Utilities
// Comprehensive collection of DateTime manipulation and calculation functions
// ============================================================================

/// Date comparison utilities
/// ========================

/// Check if two dates are the same day
bool isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}

/// Check if two dates are in the same week (Monday to Sunday)
bool isSameWeek(DateTime d1, DateTime d2) {
  DateTime startOfWeek1 = d1.subtract(Duration(days: d1.weekday - 1));
  DateTime startOfWeek2 = d2.subtract(Duration(days: d2.weekday - 1));
  return isSameDay(startOfWeek1, startOfWeek2);
}

/// Check if two dates are in the same month
bool isSameMonth(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month;
}

/// Check if two dates are in the same year
bool isSameYear(DateTime d1, DateTime d2) {
  return d1.year == d2.year;
}

/// Time calculation utilities
/// ==========================

/// Calculate decimal hours between two DateTime objects
///
/// [start] - Starting DateTime
/// [end] - Ending DateTime
/// [sameDay] - If true, normalizes dates to same day (ignores date component)
///
/// If sameDay=true and end < start, assumes next day crossing
/// Returns decimal hours (e.g., 1.5 = 1 hour 30 minutes)
double calculateDecimalHours(DateTime start, DateTime end, {bool sameDay = false}) {
  DateTime startTime = start;
  DateTime endTime = end;

  if (sameDay) {
    // Normalize to time-only using standard reference date
    startTime = timeOnly(start);
    endTime = timeOnly(end);

    // Handle midnight crossing
    if (endTime.isBefore(startTime)) {
      endTime = endTime.add(Duration(days: 1));
    }
  }

  return endTime.difference(startTime).inMinutes / 60.0;
}

/// Add or subtract decimal hours from a DateTime (algebraic operation)
///
/// [base] - Base DateTime to modify
/// [hours] - Decimal hours to add (positive) or subtract (negative)
///
/// Returns new DateTime with hours added/subtracted
/// Examples:
/// - modifyByDecimalHours(base, 1.5) adds 1h 30min
/// - modifyByDecimalHours(base, -2.25) subtracts 2h 15min
DateTime modifyByDecimalHours(DateTime base, double hours) {
  int minutes = (hours * 60).round();
  return base.add(Duration(minutes: minutes));
}

/// Validate time sequence and return difference in decimal hours
///
/// [start] - Starting DateTime
/// [end] - Ending DateTime
/// [sameDay] - If true, normalizes dates for same-day comparison
///
/// Returns:
/// - Positive value: Valid sequence (hours difference)
/// - Negative value: Invalid sequence (end before start)
/// - Zero: Same time
double validateTimeSequence(DateTime start, DateTime end, {bool sameDay = false}) {
  return calculateDecimalHours(start, end, sameDay: sameDay);
}

/// Calculate age in years from birthdate
int calculateAge(DateTime birthDate, {DateTime? referenceDate}) {
  referenceDate ??= DateTime.now();
  int age = referenceDate.year - birthDate.year;
  if (referenceDate.month < birthDate.month ||
      (referenceDate.month == birthDate.month && referenceDate.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// Period calculation utilities
/// ============================

/// Get start of day (00:00:00)
DateTime startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// Get end of day (23:59:59.999)
DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

/// Get start of week (Monday 00:00:00)
DateTime startOfWeek(DateTime date) {
  int daysFromMonday = date.weekday - 1;
  return startOfDay(date.subtract(Duration(days: daysFromMonday)));
}

/// Get end of week (Sunday 23:59:59.999)
DateTime endOfWeek(DateTime date) {
  int daysToSunday = 7 - date.weekday;
  return endOfDay(date.add(Duration(days: daysToSunday)));
}

/// Get start of month (1st day 00:00:00)
DateTime startOfMonth(DateTime date) {
  return DateTime(date.year, date.month, 1);
}

/// Get end of month (last day 23:59:59.999)
DateTime endOfMonth(DateTime date) {
  DateTime nextMonth = date.month == 12
    ? DateTime(date.year + 1, 1, 1)
    : DateTime(date.year, date.month + 1, 1);
  return endOfDay(nextMonth.subtract(Duration(days: 1)));
}

/// Get start of year (January 1st 00:00:00)
DateTime startOfYear(DateTime date) {
  return DateTime(date.year, 1, 1);
}

/// Get end of year (December 31st 23:59:59.999)
DateTime endOfYear(DateTime date) {
  return DateTime(date.year, 12, 31, 23, 59, 59, 999);
}

/// Time rounding and normalization
/// ===============================

/// Round DateTime to nearest minute interval
DateTime roundToMinutes(DateTime date, int minutes) {
  int totalMinutes = date.hour * 60 + date.minute;
  int roundedMinutes = (totalMinutes / minutes).round() * minutes;

  return DateTime(
    date.year, date.month, date.day,
    roundedMinutes ~/ 60,
    roundedMinutes % 60
  );
}

/// Round DateTime to nearest hour
DateTime roundToHour(DateTime date) {
  int roundedHour = date.minute >= 30 ? date.hour + 1 : date.hour;
  return DateTime(date.year, date.month, date.day, roundedHour);
}

/// Set specific time on a date (keeping date, changing time)
DateTime setTimeOnDate(DateTime date, int hour, int minute, [int second = 0]) {
  return DateTime(date.year, date.month, date.day, hour, minute, second);
}

/// Extract only time component (using reference date 1970-01-01)
DateTime timeOnly(DateTime dateTime) {
  return DateTime(1970, 1, 1, dateTime.hour, dateTime.minute, dateTime.second);
}

/// Extract only date component (time set to 00:00:00)
DateTime dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

/// Work time utilities
/// ===================

/// Check if date falls on weekend (Saturday or Sunday)
bool isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Check if date falls on working day (Monday to Friday)
bool isWorkingDay(DateTime date) {
  return !isWeekend(date);
}

/// Check if time is within business hours
bool isBusinessHours(DateTime dateTime, {int startHour = 8, int endHour = 18}) {
  int hour = dateTime.hour;
  return hour >= startHour && hour < endHour;
}

/// Check if time falls in morning (before noon)
bool isMorning(DateTime dateTime) {
  return dateTime.hour < 12;
}

/// Check if time falls in afternoon (12:00-17:59)
bool isAfternoon(DateTime dateTime) {
  return dateTime.hour >= 12 && dateTime.hour < 18;
}

/// Check if time falls in evening (18:00 onwards)
bool isEvening(DateTime dateTime) {
  return dateTime.hour >= 18;
}

/// Date range and validation utilities
/// ===================================

/// Check if date is within specified range (inclusive)
bool isDateInRange(DateTime date, DateTime start, DateTime end) {
  DateTime dateOnly = startOfDay(date);
  DateTime startOnly = startOfDay(start);
  DateTime endOnly = startOfDay(end);

  return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
}

/// Check if date is in the past (before today)
bool isPast(DateTime date) {
  return startOfDay(date).isBefore(startOfDay(DateTime.now()));
}

/// Check if date is in the future (after today)
bool isFuture(DateTime date) {
  return startOfDay(date).isAfter(startOfDay(DateTime.now()));
}

/// Check if date is today
bool isToday(DateTime date) {
  return isSameDay(date, DateTime.now());
}

/// Get number of days between two dates
int daysBetween(DateTime start, DateTime end) {
  DateTime startDay = startOfDay(start);
  DateTime endDay = startOfDay(end);
  return endDay.difference(startDay).inDays;
}

/// Get working days between two dates (excluding weekends)
int workingDaysBetween(DateTime start, DateTime end) {
  int totalDays = daysBetween(start, end);
  int workingDays = 0;

  for (int i = 0; i <= totalDays; i++) {
    DateTime currentDate = start.add(Duration(days: i));
    if (isWorkingDay(currentDate)) {
      workingDays++;
    }
  }

  return workingDays;
}

/// Formatting utilities
/// ====================

/// Format time as decimal hours (e.g., "8.50" for 8:30)
String formatAsDecimalHours(DateTime time) {
  double decimal = time.hour + (time.minute / 60.0);
  return decimal.toStringAsFixed(2);
}

/// Format duration as hours:minutes (e.g., "2:30")
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  int hours = duration.inHours;
  int minutes = duration.inMinutes.remainder(60);
  return '$hours:${twoDigits(minutes)}';
}

/// Format time range (e.g., "08:30-17:45")
String formatTimeRange(DateTime start, DateTime end, {String separator = '-'}) {
  String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${formatTime(start)}$separator${formatTime(end)}';
}

/// Seasonal and calendar utilities
/// ===============================

/// Seasons for Northern Hemisphere
enum Season { spring, summer, autumn, winter }

/// Get season for Northern Hemisphere
Season getSeason(DateTime date) {
  int month = date.month;
  switch (month) {
    case 3: case 4: case 5: return Season.spring;
    case 6: case 7: case 8: return Season.summer;
    case 9: case 10: case 11: return Season.autumn;
    default: return Season.winter;
  }
}

/// Get quarter of the year (1-4)
int getQuarter(DateTime date) {
  return ((date.month - 1) ~/ 3) + 1;
}

/// Check if year is leap year
bool isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

/// Get days in month
int daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}