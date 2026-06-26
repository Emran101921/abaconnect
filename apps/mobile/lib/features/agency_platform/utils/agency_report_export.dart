import 'package:intl/intl.dart';

import '../../../features/agency/data/agency_repository.dart';
import '../data/agency_platform_repository.dart';
import '../../../shared/models/analytics_metric.dart';

String productivityReportCsv(
  List<AnalyticsMetricModel> metrics,
  AnalyticsDateRangeLabel rangeLabel,
) {
  return _buildCsv(
    ['metric_key', 'value', 'prior_period_value', 'date_range'],
    metrics
        .map(
          (metric) => [
            metric.metricKey,
            metric.metricValue.toString(),
            metric.priorPeriodValue?.toString() ?? '',
            rangeLabel,
          ],
        )
        .toList(),
  );
}

String complianceReportCsv(List<StaffSessionNoteSummaryModel> notes) {
  return _buildCsv(
    [
      'session_id',
      'child_name',
      'therapist_name',
      'session_date',
      'fully_signed',
      'has_service_log',
      'awaiting_parent_signature',
    ],
    notes
        .map(
          (note) => [
            note.sessionId,
            note.childName,
            note.therapistName,
            note.sessionDate ?? '',
            note.isFullySigned.toString(),
            note.hasServiceLog.toString(),
            note.awaitingParentSignature.toString(),
          ],
        )
        .toList(),
  );
}

String auditReportCsv(List<AgencyAuditLogModel> logs) {
  return _buildCsv(
    ['id', 'action', 'entity_type', 'entity_id', 'patient_id', 'actor_role', 'created_at'],
    logs
        .map(
          (log) => [
            log.id,
            log.action,
            log.entityType,
            log.entityId ?? '',
            log.patientId ?? '',
            log.actorRole ?? '',
            DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt),
          ],
        )
        .toList(),
  );
}

String payrollRunCsv(AgencyPayrollRunPreviewModel preview) {
  return _buildCsv(
    [
      'therapist_id',
      'therapist_name',
      'session_count',
      'hours',
      'rate',
      'estimated_pay_usd',
    ],
    preview.lines
        .map(
          (line) => [
            line.therapistId,
            line.therapistName,
            line.sessionCount.toString(),
            line.hours.toStringAsFixed(2),
            line.rateDisplay,
            (line.estimatedPayCents / 100).toStringAsFixed(2),
          ],
        )
        .toList(),
  );
}

String _buildCsv(List<String> headers, List<List<String>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_csvCell).join(','));
  }
  return buffer.toString();
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

typedef AnalyticsDateRangeLabel = String;
