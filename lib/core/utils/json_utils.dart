/// Small, dependency-free helpers for reading values out of decoded JSON.
int asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double asDouble(Object? value, double fallback) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return fallback;
}

String asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime? asDateTime(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((Object? key, Object? item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((Map item) => asMap(item))
      .toList(growable: false);
}

List<String> asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}

List<Object?> asList(Object? value) {
  if (value is! List) return const <Object?>[];
  return value;
}
