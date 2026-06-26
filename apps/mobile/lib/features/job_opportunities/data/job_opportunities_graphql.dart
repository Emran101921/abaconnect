/// Shared GraphQL field selections and document builders for job marketplace.
const jobApplicationFields =
    'id status message therapistName therapistEmail '
    'jobOpportunityId jobTitle createdAt updatedAt '
    'credentialDocuments { id title fileName type uploadedAt } '
    'recentStatusHistory { fromStatus toStatus note changedByName createdAt }';

const jobInterviewFields =
    'id applicationId jobOpportunityId jobTitle therapistName therapistEmail '
    'agencyName scheduledAt durationMinutes status recordingRequested '
    'agencyRecordingConsent therapistRecordingConsent recordingEnabled '
    'notes callSessionId';

String myJobApplicationsDocument() =>
    'query MyJobApplications { myJobApplications { $jobApplicationFields } }';

String agencyJobApplicationsDocument() =>
    'query AgencyJobApplications(\$jobOpportunityId: ID) {'
    ' agencyJobApplications(jobOpportunityId: \$jobOpportunityId) {'
    ' $jobApplicationFields'
    ' }'
    '}';

String adminJobApplicationsDocument() =>
    'query AdminJobApplications { adminJobApplications { $jobApplicationFields } }';

String myJobInterviewsDocument() =>
    'query MyJobInterviews { myJobInterviews { $jobInterviewFields } }';
