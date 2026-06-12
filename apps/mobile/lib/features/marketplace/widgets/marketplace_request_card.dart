import 'package:flutter/material.dart';

import '../data/marketplace_repository.dart';

class MarketplaceRequestCard extends StatelessWidget {
  const MarketplaceRequestCard({
    super.key,
    required this.request,
    this.onAvailable,
    this.onRequestPermission,
    this.onViewAuthorizedDetails,
    this.onReport,
    this.showProviderActions = false,
  });

  final MarketplaceRequestModel request;
  final VoidCallback? onAvailable;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onViewAuthorizedDetails;
  final VoidCallback? onReport;
  final bool showProviderActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request ${request.anonymousPublicId}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _row('Service area', request.serviceAreaLabel),
            if (request.distanceMiles != null)
              _row('Distance', '${request.distanceMiles} miles'),
            _row('Age range', request.ageRangeLabel),
            _row(
              'Service categories',
              request.serviceCategories.join(', '),
            ),
            _row('Concern tags', request.concernTags.join(', ')),
            if (request.languagePreference != null)
              _row('Language', request.languagePreference!),
            _row('Location type', request.locationType),
            _row('Authorization', request.authorizationStatusLabel),
            if (request.publicDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                request.publicDescription!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (showProviderActions) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: onAvailable,
                    child: const Text("I'm available"),
                  ),
                  OutlinedButton(
                    onPressed: onRequestPermission,
                    child: const Text('Request parent permission'),
                  ),
                  if (onViewAuthorizedDetails != null)
                    TextButton(
                      onPressed: onViewAuthorizedDetails,
                      child: const Text('Authorized child details'),
                    ),
                  if (onReport != null)
                    TextButton(
                      onPressed: onReport,
                      child: const Text('Report listing'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
