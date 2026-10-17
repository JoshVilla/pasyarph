import 'enums.dart';
import 'json.dart';

/// Row of `reports`. Users can file and see their own reports only.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final ReportTarget targetType;
  final String targetId;
  final String reason;
  final DateTime createdAt;

  factory Report.fromJson(Json json) => Report(
    id: json['id'] as String,
    reporterId: json['reporter_id'] as String,
    targetType: ReportTarget.fromValue(json['target_type'] as String),
    targetId: json['target_id'] as String,
    reason: json['reason'] as String,
    createdAt: parseTimestamp(json['created_at']),
  );

  /// Insert payload. `reporter_id` defaults to the signed-in user.
  static Json insertJson({
    required ReportTarget targetType,
    required String targetId,
    required String reason,
  }) => {
    'target_type': targetType.value,
    'target_id': targetId,
    'reason': reason,
  };
}
