import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_gradient_header.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_welcome_banner.dart';
import '../../../shared/widgets/app_risk_badge.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../data/parent_booking_repository.dart';

class ScreeningResultsScreen extends ConsumerStatefulWidget {
  const ScreeningResultsScreen({
    super.key,
    required this.child,
    required this.result,
  });

  final ChildModel child;
  final ScreeningResultModel result;

  @override
  ConsumerState<ScreeningResultsScreen> createState() =>
      _ScreeningResultsScreenState();
}

class _ScreeningResultsScreenState
    extends ConsumerState<ScreeningResultsScreen> {
  bool _requestingEvaluation = false;

  ChildModel get child => widget.child;
  ScreeningResultModel get result => widget.result;

  String get _ageLabel {
    final now = DateTime.now();
    var years = now.year - child.dateOfBirth.year;
    final birthdayPassed =
        now.month > child.dateOfBirth.month ||
        (now.month == child.dateOfBirth.month &&
            now.day >= child.dateOfBirth.day);
    if (!birthdayPassed) years -= 1;
    if (years < 1) {
      final months = (now.difference(child.dateOfBirth).inDays / 30).floor();
      return '$months mo';
    }
    return '$years yr';
  }

  Future<void> _requestEvaluation() async {
    setState(() => _requestingEvaluation = true);
    try {
      await ref
          .read(parentBookingRepositoryProvider)
          .requestEarlyInterventionEvaluation(result.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline),
          title: const Text('Evaluation requested'),
          content: const Text(
            'Your request has been submitted. A care coordinator will follow up '
            'to schedule an evaluation based on the screening recommendations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        context.push(AppRoutes.parentAppointments);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request evaluation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingEvaluation = false);
    }
  }

  void _matchProviders() {
    final therapyTypes = result.recommendedTherapyTypes;
    final uri = therapyTypes.isEmpty
        ? AppRoutes.matching
        : '${AppRoutes.matching}?therapyTypes=${therapyTypes.join(',')}';
    context.push(uri);
  }

  @override
  Widget build(BuildContext context) {
    final risk = result.riskLevel ?? 'UNKNOWN';

    return AppScaffold(
      title: 'Screening Results',
      subtitle: 'Early Intervention summary',
      body: AppContentContainer(
        padding: EdgeInsets.zero,
        child: ListView(
          children: [
            AppGradientHeader(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Age $_ageLabel · ${DateFormat.yMMMd().format(child.dateOfBirth)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Overall risk level',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            AppRiskBadge(level: risk),
                            if (result.score != null) ...[
                              const Spacer(),
                              Text(
                                'Score ${result.score!.toStringAsFixed(1)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const AppHealthcareIllustration(
                    type: AppIllustrationType.screening,
                    size: 80,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader(
                    title: 'Recommended services',
                    subtitle: 'Based on your screening responses',
                  ),
                  const SizedBox(height: 8),
                  if (result.recommendations.isEmpty)
                    AppDashboardCard(
                      elevated: false,
                      child: Text(
                        'No specific service recommendations at this time. '
                        'Continue monitoring development and consult your pediatrician.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ...result.recommendations.map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppDashboardCard(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Text(rec.service.characters.first),
                            ),
                            title: Text(rec.service),
                            subtitle: Text(rec.explanation),
                            isThreeLine: true,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppDashboardCard(
                    elevated: false,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      'This screening is informational only. It is not a diagnosis, '
                      'medical advice, or a replacement for evaluation by a licensed '
                      'professional. Possible service categories to explore may be '
                      'listed above. Recommended next step: professional evaluation/referral.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AppSectionHeader(
                    title: 'Next steps',
                    subtitle: 'Take action on your screening results',
                  ),
                  const SizedBox(height: 12),
                  AppQuickActionCard(
                    title: _requestingEvaluation
                        ? 'Submitting…'
                        : 'Request evaluation',
                    subtitle: 'Schedule a licensed professional evaluation',
                    icon: Icons.medical_services_outlined,
                    onTap: _requestingEvaluation ? null : _requestEvaluation,
                  ),
                  const SizedBox(height: 8),
                  AppQuickActionCard(
                    title: 'Create anonymous marketplace request',
                    subtitle:
                        'Let verified providers respond by ZIP area without sharing child identity',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () {
                      context.push(
                        '${AppRoutes.parentMarketplaceOptIn}'
                        '?childId=${child.id}'
                        '&screeningResponseId=${result.id}'
                        '${child.primaryLanguage != null ? '&languagePreference=${Uri.encodeComponent(child.primaryLanguage!)}' : ''}',
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  AppQuickActionCard(
                    title: 'Match providers',
                    subtitle: 'Find therapists aligned with recommendations',
                    icon: Icons.people_outline,
                    onTap: _matchProviders,
                  ),
                  const SizedBox(height: 8),
                  AppQuickActionCard(
                    title: 'Upload documents',
                    subtitle: 'Share records with your care team',
                    icon: Icons.upload_file,
                    onTap: () => context.push(AppRoutes.documents),
                  ),
                  const SizedBox(height: 8),
                  AppQuickActionCard(
                    title: 'Contact care coordinator',
                    subtitle: 'Get help navigating next steps',
                    icon: Icons.support_agent,
                    onTap: () => context.push(AppRoutes.messages),
                  ),
                  const SizedBox(height: 8),
                  AppQuickActionCard(
                    title: 'Re-screen this child',
                    subtitle: 'Start a new screening or continue from draft',
                    icon: Icons.edit_note,
                    onTap: () {
                      context.push(
                        '${AppRoutes.parentScreening}?childId=${child.id}&autoStart=true',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.parentHome),
                      child: const Text('Back to home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
