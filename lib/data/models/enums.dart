/// Postgres enums from supabase/migrations. [value] is the database string.
library;

T _byValue<T extends Enum>(
  List<T> values,
  String value,
  String Function(T) of,
) => values.firstWhere(
  (e) => of(e) == value,
  orElse: () => throw FormatException('Unknown ${T.toString()}: $value'),
);

enum BikeType {
  scooter('scooter'),
  underbone('underbone'),
  bigBike('big_bike'),
  dualSport('dual_sport');

  const BikeType(this.value);
  final String value;

  static BikeType fromValue(String value) =>
      _byValue(values, value, (e) => e.value);
}

enum LoopSource {
  generated('generated'),
  custom('custom');

  const LoopSource(this.value);
  final String value;

  static LoopSource fromValue(String value) =>
      _byValue(values, value, (e) => e.value);
}

enum LoopVisibility {
  public('public'),
  club('club'),
  private('private');

  const LoopVisibility(this.value);
  final String value;

  static LoopVisibility fromValue(String value) =>
      _byValue(values, value, (e) => e.value);
}

enum ClubRole {
  owner('owner'),
  member('member');

  const ClubRole(this.value);
  final String value;

  static ClubRole fromValue(String value) =>
      _byValue(values, value, (e) => e.value);
}

enum ReportTarget {
  post('post'),
  comment('comment'),
  loop('loop'),
  user('user');

  const ReportTarget(this.value);
  final String value;

  static ReportTarget fromValue(String value) =>
      _byValue(values, value, (e) => e.value);
}
