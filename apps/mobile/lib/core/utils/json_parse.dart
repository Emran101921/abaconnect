String jsonString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? jsonOptionalString(dynamic value) {
  final parsed = jsonString(value);
  return parsed.isEmpty ? null : parsed;
}

String jsonRequiredId(dynamic value, String label) {
  final parsed = jsonString(value);
  if (parsed.isEmpty) {
    throw Exception('Missing $label in response');
  }
  return parsed;
}

DateTime jsonDateTime(dynamic value, {DateTime? fallback}) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return fallback ?? DateTime.now();
}

DateTime? jsonDateTimeOrNull(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
