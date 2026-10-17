/// Small helpers for reading Supabase JSON rows.
library;

typedef Json = Map<String, dynamic>;

DateTime parseTimestamp(Object? value) => DateTime.parse(value! as String);

DateTime? parseTimestampOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

double? toDoubleOrNull(Object? value) => (value as num?)?.toDouble();

int? toIntOrNull(Object? value) => (value as num?)?.toInt();
