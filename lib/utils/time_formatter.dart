/// Utility function to convert 24-hour time string to 12-hour format
/// Input: "14:30" or "2:15"
/// Output: "2:30 PM" or "2:15 AM"
String formatTime12Hour(String timeString) {
  try {
    final parts = timeString.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$hour:$minute $period';
  } catch (e) {
    return timeString; // Return original if parsing fails
  }
}

/// Utility function to format DateTime into 12-hour format
/// Input: DateTime(2026, 3, 17, 14, 30)
/// Output: "2:30 PM"
String formatDateTime12Hour(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

  return '$displayHour:$minute $period';
}

/// Format date to readable string
/// Input: DateTime(2026, 3, 17)
/// Output: "Mar 17, 2026"
String formatDate(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
