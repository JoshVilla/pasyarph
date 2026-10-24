/// Why a rider reports something. The label is what moderators read.
enum ReportReason {
  spam('Spam or selling'),
  harassment('Harassment or hate'),
  dangerous('Dangerous or illegal riding'),
  explicit('Nudity or violence'),
  wrongPlace('Wrong place or fake route'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

/// `reports.reason` allows 500 characters.
const maxReportReason = 500;

/// What's stored: "Spam or selling", or "Something else: …details".
String reportReasonText(ReportReason reason, String details) {
  final d = details.trim().replaceAll(RegExp(r'\s+'), ' ');
  final text = d.isEmpty ? reason.label : '${reason.label}: $d';
  return text.length <= maxReportReason
      ? text
      : text.substring(0, maxReportReason);
}

/// "Something else" needs a few words so moderators know what to look at.
bool reportNeedsDetails(ReportReason reason, String details) =>
    reason == ReportReason.other && details.trim().length < 3;
