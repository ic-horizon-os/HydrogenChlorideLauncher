String formatDuration(Duration duration, {bool compact = false}) {
  if (duration.inSeconds <= 0) return compact ? '0m' : '0 分钟';
  if (compact) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes % 60;
  if (hours == 0) return '${duration.inMinutes} 分钟';
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}

String formatPlaytime(int milliseconds) {
  return formatDuration(Duration(milliseconds: milliseconds));
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String digits = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$digits ${units[unit]}';
}

String formatCount(int count) {
  if (count >= 100000000) {
    return '${(count / 100000000).toStringAsFixed(1)} 亿';
  }
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)} 万';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return '$count';
}

String formatRelativeTime(DateTime? time) {
  if (time == null) return '从未启动';
  final Duration difference = DateTime.now().difference(time);
  if (difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  if (difference.inDays == 1) return '昨天';
  if (difference.inDays < 30) return '${difference.inDays} 天前';
  return formatDate(time);
}

String formatDate(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

String formatDateTime(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '${formatDate(time)} $hour:$minute';
}

String formatShortDate(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  return '$month/$day';
}

String formatClock(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes % 60;
  final int seconds = duration.inSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
