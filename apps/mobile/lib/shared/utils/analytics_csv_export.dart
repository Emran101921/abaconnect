import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/file_download.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/agency/data/agency_repository.dart';

const _claimHeaders = [
  'id',
  'claim_number',
  'child_name',
  'payer_name',
  'status',
  'service_date',
  'billed_amount',
];

const _screeningHeaders = [
  'id',
  'child_name',
  'template_name',
  'risk_level',
  'score',
  'completed_at',
];

String _csvCell(String? value) {
  final text = value ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _buildCsv(List<String> headers, List<List<String>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_csvCell).join(','));
  }
  return buffer.toString();
}

String claimsCsvFromAdmin(List<AnalyticsClaimSummaryModel> claims) {
  return _buildCsv(
    _claimHeaders,
    claims
        .map(
          (c) => [
            c.id,
            c.claimNumber ?? '',
            c.childName ?? '',
            c.payerName,
            c.status,
            DateFormat('yyyy-MM-dd').format(c.serviceDate),
            c.billedAmount.toStringAsFixed(2),
          ],
        )
        .toList(),
  );
}

String claimsCsvFromAgency(List<AgencyClaimSummaryModel> claims) {
  return _buildCsv(
    _claimHeaders,
    claims
        .map(
          (c) => [
            c.id,
            c.claimNumber ?? '',
            c.childName ?? '',
            c.payerName,
            c.status,
            DateFormat('yyyy-MM-dd').format(c.serviceDate),
            c.billedAmount.toStringAsFixed(2),
          ],
        )
        .toList(),
  );
}

String screeningsCsvFromAdmin(List<AnalyticsScreeningSummaryModel> screenings) {
  return _buildCsv(
    _screeningHeaders,
    screenings
        .map(
          (s) => [
            s.id,
            s.childName ?? '',
            s.templateName ?? '',
            s.riskLevel ?? '',
            s.score?.toString() ?? '',
            DateFormat('yyyy-MM-dd').format(s.completedAt),
          ],
        )
        .toList(),
  );
}

String screeningsCsvFromAgency(List<AgencyScreeningSummaryModel> screenings) {
  return _buildCsv(
    _screeningHeaders,
    screenings
        .map(
          (s) => [
            s.id,
            s.childName ?? '',
            s.templateName ?? '',
            s.riskLevel ?? '',
            s.score?.toString() ?? '',
            DateFormat('yyyy-MM-dd').format(s.completedAt),
          ],
        )
        .toList(),
  );
}

String analyticsExportFilename(String prefix, String filter) {
  final slug = filter.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return '$prefix-$slug-$date.csv';
}

Future<void> exportAnalyticsCsv(
  BuildContext context, {
  required String csv,
  required String filename,
}) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final path = await downloadBytes(bytes, filename);
    if (!context.mounted) return;
    final message = kIsWeb
        ? 'CSV downloaded'
        : (path.isNotEmpty ? 'Saved to $path' : 'CSV saved');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
