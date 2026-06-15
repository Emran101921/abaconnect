import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';

class MarketplaceRequestModel {
  const MarketplaceRequestModel({
    required this.id,
    required this.anonymousPublicId,
    required this.serviceAreaLabel,
    required this.ageRangeLabel,
    required this.serviceCategories,
    required this.concernTags,
    required this.locationType,
    required this.authorizationStatusLabel,
    required this.urgency,
    required this.status,
    this.languagePreference,
    this.publicDescription,
    this.distanceMiles,
    this.mapPinLat,
    this.mapPinLng,
    this.interestCount = 0,
    this.pendingInterestCount = 0,
    this.matchScore,
    this.childId,
  });

  final String id;
  final String anonymousPublicId;
  final String serviceAreaLabel;
  final String ageRangeLabel;
  final List<String> serviceCategories;
  final List<String> concernTags;
  final String locationType;
  final String authorizationStatusLabel;
  final String urgency;
  final String status;
  final String? languagePreference;
  final String? publicDescription;
  final double? distanceMiles;
  final double? mapPinLat;
  final double? mapPinLng;
  final int interestCount;
  final int pendingInterestCount;
  final double? matchScore;
  final String? childId;

  int get reviewableInterestCount =>
      pendingInterestCount > 0 ? pendingInterestCount : interestCount;
}

class MarketplaceConsentModel {
  const MarketplaceConsentModel({
    required this.id,
    required this.consentType,
    required this.consentTextVersion,
    required this.granted,
    required this.createdAt,
    this.revokedAt,
    this.providerId,
    this.providerName,
    this.providerAccountType,
  });

  final String id;
  final String consentType;
  final String consentTextVersion;
  final bool granted;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final String? providerId;
  final String? providerName;
  final String? providerAccountType;

  bool get isActiveShareConsent =>
      consentType == 'SHARE_IDENTIFIABLE_INFO' &&
      granted &&
      revokedAt == null;
}

class AuthorizedChildDetailsModel {
  const AuthorizedChildDetailsModel({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.zipCode,
    required this.parentName,
    required this.marketplaceRequestId,
    required this.anonymousPublicId,
    this.city,
    this.state,
    this.primaryLanguage,
    this.parentEmail,
    this.parentPhone,
    this.sharedDocuments = const [],
  });

  final String childId;
  final String firstName;
  final String lastName;
  final String zipCode;
  final String? city;
  final String? state;
  final String? primaryLanguage;
  final String parentName;
  final String? parentEmail;
  final String? parentPhone;
  final String marketplaceRequestId;
  final String anonymousPublicId;
  final List<MarketplaceSharedDocumentModel> sharedDocuments;
}

class MarketplaceSharedDocumentModel {
  const MarketplaceSharedDocumentModel({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.uploadedAt,
  });

  final String id;
  final String title;
  final String fileName;
  final String type;
  final DateTime uploadedAt;
}

class MarketplaceInterestModel {
  const MarketplaceInterestModel({
    required this.id,
    required this.status,
    required this.providerName,
    required this.providerId,
    required this.accountType,
    required this.verifiedStatus,
    this.message,
  });

  final String id;
  final String status;
  final String providerName;
  final String providerId;
  final String accountType;
  final String verifiedStatus;
  final String? message;
}

class ProviderMarketplaceProfileModel {
  const ProviderMarketplaceProfileModel({
    required this.id,
    required this.displayName,
    required this.verifiedStatus,
    required this.confidentialityTermsAccepted,
  });

  final String id;
  final String displayName;
  final String verifiedStatus;
  final bool confidentialityTermsAccepted;

  bool get isReady =>
      confidentialityTermsAccepted && verifiedStatus != 'SUSPENDED';
}

class MarketplaceSavedSearchModel {
  const MarketplaceSavedSearchModel({
    required this.id,
    required this.name,
    required this.alertsEnabled,
    required this.createdAt,
    this.zipCode,
    this.radiusMiles,
    this.serviceCategory,
    this.ageRange,
    this.language,
    this.locationType,
    this.urgency,
    this.authorizationStatus,
  });

  final String id;
  final String name;
  final bool alertsEnabled;
  final DateTime createdAt;
  final String? zipCode;
  final double? radiusMiles;
  final String? serviceCategory;
  final String? ageRange;
  final String? language;
  final String? locationType;
  final String? urgency;
  final String? authorizationStatus;
}

class MarketplaceRepository {
  MarketplaceRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  Future<ProviderMarketplaceProfileModel?> fetchProviderProfile() async {
    const query = r'''
      query {
        myProviderMarketplaceProfile {
          id
          displayName
          verifiedStatus
          confidentialityTermsAccepted
        }
      }
    ''';
    final result = await _graphql.query(query);
    final row =
        result['data']?['myProviderMarketplaceProfile'] as Map<String, dynamic>?;
    if (row == null) return null;
    return ProviderMarketplaceProfileModel(
      id: row['id'] as String,
      displayName: row['displayName'] as String,
      verifiedStatus: row['verifiedStatus'] as String,
      confidentialityTermsAccepted:
          row['confidentialityTermsAccepted'] as bool? ?? false,
    );
  }

  Future<void> completeProviderOnboarding({
    required String legalName,
    required String displayName,
    String? licenseNumber,
    String? npi,
    required List<String> serviceCategories,
    required List<String> coverageZipCodes,
    required List<String> languages,
    required bool confidentialityTermsAccepted,
    String accountType = 'THERAPIST',
  }) async {
    const mutation = r'''
      mutation($input: CompleteProviderMarketplaceOnboardingInput!) {
        completeProviderMarketplaceOnboarding(input: $input) {
          id
        }
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'accountType': accountType,
        'legalName': legalName,
        'displayName': displayName,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (npi != null) 'npi': npi,
        'serviceCategories': serviceCategories,
        'coverageZipCodes': coverageZipCodes,
        'languages': languages,
        'confidentialityTermsAccepted': confidentialityTermsAccepted,
      },
    });
  }

  Future<void> pauseRequest(String marketplaceRequestId) async {
    const mutation = r'''
      mutation($id: ID!) {
        pauseMarketplaceRequest(marketplaceRequestId: $id)
      }
    ''';
    await _graphql.query(mutation, variables: {'id': marketplaceRequestId});
  }

  Future<void> closeRequest(String marketplaceRequestId) async {
    const mutation = r'''
      mutation($id: ID!) {
        closeMarketplaceRequest(marketplaceRequestId: $id)
      }
    ''';
    await _graphql.query(mutation, variables: {'id': marketplaceRequestId});
  }

  Future<void> resumeRequest(String marketplaceRequestId) async {
    const mutation = r'''
      mutation($id: ID!) {
        resumeMarketplaceRequest(marketplaceRequestId: $id)
      }
    ''';
    await _graphql.query(mutation, variables: {'id': marketplaceRequestId});
  }

  Future<void> rejectInterest({
    required String marketplaceRequestId,
    required String providerProfileId,
  }) async {
    const mutation = r'''
      mutation($requestId: ID!, $providerId: ID!) {
        rejectMarketplaceInterest(
          marketplaceRequestId: $requestId
          providerProfileId: $providerId
        )
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'requestId': marketplaceRequestId,
        'providerId': providerProfileId,
      },
    );
  }

  Future<MarketplaceRequestModel> createRequest({
    required String childId,
    String? screeningResponseId,
    required bool anonymousConsentGranted,
    required String locationType,
    String? languagePreference,
    String? urgency,
    String? publicDescription,
  }) async {
    const mutation = r'''
      mutation Create($input: CreateMarketplaceRequestInput!) {
        createMarketplaceRequest(input: $input) {
          id
          anonymousPublicId
          serviceAreaLabel
          ageRangeLabel
          serviceCategories
          concernTags
          locationType
          authorizationStatusLabel
          urgency
          status
          languagePreference
          publicDescription
        }
      }
    ''';
    final result = await _graphql.query(mutation, variables: {
      'input': {
        'childId': childId,
        if (screeningResponseId != null)
          'screeningResponseId': screeningResponseId,
        'anonymousConsentGranted': anonymousConsentGranted,
        'locationType': locationType,
        if (languagePreference != null)
          'languagePreference': languagePreference,
        if (urgency != null) 'urgency': urgency,
        if (publicDescription != null) 'publicDescription': publicDescription,
      },
    });
    final row =
        result['data']?['createMarketplaceRequest'] as Map<String, dynamic>?;
    if (row == null) {
      throw Exception('Failed to create marketplace request');
    }
    return _mapRequest(row);
  }

  Future<List<MarketplaceRequestModel>> fetchMyRequests() async {
    const query = r'''
      query {
        myMarketplaceRequests {
          id
          anonymousPublicId
          serviceAreaLabel
          ageRangeLabel
          serviceCategories
          concernTags
          locationType
          authorizationStatusLabel
          urgency
          status
          languagePreference
          publicDescription
          interestCount
          pendingInterestCount
          childId
          mapPinLat
          mapPinLng
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['myMarketplaceRequests'] as List<dynamic>? ?? [];
    return list
        .map((e) => _mapRequest(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketplaceInterestModel>> fetchInterests(
    String marketplaceRequestId,
  ) async {
    const query = r'''
      query($id: ID!) {
        marketplaceRequestInterests(marketplaceRequestId: $id) {
          id
          status
          message
          provider {
            id
            displayName
            accountType
            verifiedStatus
          }
        }
      }
    ''';
    final result = await _graphql.query(query, variables: {'id': marketplaceRequestId});
    final list =
        result['data']?['marketplaceRequestInterests'] as List<dynamic>? ?? [];
    return list.map((e) {
      final row = e as Map<String, dynamic>;
      final provider = row['provider'] as Map<String, dynamic>;
      return MarketplaceInterestModel(
        id: row['id'] as String,
        status: row['status'] as String,
        message: row['message'] as String?,
        providerId: provider['id'] as String,
        providerName: provider['displayName'] as String,
        accountType: provider['accountType'] as String,
        verifiedStatus: provider['verifiedStatus'] as String,
      );
    }).toList();
  }

  Future<List<MarketplaceRequestModel>> browseRequests({
    String? zipCode,
    double? radiusMiles,
    String? serviceCategory,
    String? ageRange,
    String? language,
    String? locationType,
    String? urgency,
    String? authorizationStatus,
  }) async {
    const query = r'''
      query($input: MarketplaceBrowseInput) {
        browseMarketplaceRequests(input: $input) {
          id
          anonymousPublicId
          serviceAreaLabel
          distanceMiles
          ageRangeLabel
          serviceCategories
          concernTags
          languagePreference
          locationType
          authorizationStatusLabel
          urgency
          publicDescription
          mapPinLat
          mapPinLng
          matchScore
        }
      }
    ''';
    final result = await _graphql.query(query, variables: {
      'input': {
        if (zipCode != null) 'zipCode': zipCode,
        if (radiusMiles != null) 'radiusMiles': radiusMiles,
        if (serviceCategory != null) 'serviceCategory': serviceCategory,
        if (ageRange != null) 'ageRange': ageRange,
        if (language != null) 'language': language,
        if (locationType != null) 'locationType': locationType,
        if (urgency != null) 'urgency': urgency,
        if (authorizationStatus != null)
          'authorizationStatus': authorizationStatus,
      },
    });
    final list =
        result['data']?['browseMarketplaceRequests'] as List<dynamic>? ?? [];
    return list
        .map((e) => _mapRequest(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitInterest({
    required String marketplaceRequestId,
    String? message,
  }) async {
    const mutation = r'''
      mutation($input: SubmitMarketplaceInterestInput!) {
        submitMarketplaceInterest(input: $input)
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'marketplaceRequestId': marketplaceRequestId,
        if (message != null) 'message': message,
      },
    });
  }

  Future<List<MarketplaceSavedSearchModel>> fetchSavedSearches() async {
    const query = r'''
      query {
        myMarketplaceSavedSearches {
          id
          name
          alertsEnabled
          createdAt
          zipCode
          radiusMiles
          serviceCategory
          ageRange
          language
          locationType
          urgency
          authorizationStatus
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['myMarketplaceSavedSearches'] as List<dynamic>? ?? [];
    return list.map((e) {
      final row = e as Map<String, dynamic>;
      return MarketplaceSavedSearchModel(
        id: row['id'] as String,
        name: row['name'] as String,
        alertsEnabled: row['alertsEnabled'] as bool? ?? true,
        createdAt: DateTime.parse(row['createdAt'] as String),
        zipCode: row['zipCode'] as String?,
        radiusMiles: (row['radiusMiles'] as num?)?.toDouble(),
        serviceCategory: row['serviceCategory'] as String?,
        ageRange: row['ageRange'] as String?,
        language: row['language'] as String?,
        locationType: row['locationType'] as String?,
        urgency: row['urgency'] as String?,
        authorizationStatus: row['authorizationStatus'] as String?,
      );
    }).toList();
  }

  Future<MarketplaceSavedSearchModel> saveSearch({
    required String name,
    String? zipCode,
    double? radiusMiles,
    String? serviceCategory,
    String? ageRange,
    String? language,
    String? locationType,
    String? urgency,
    String? authorizationStatus,
    bool alertsEnabled = true,
  }) async {
    const mutation = r'''
      mutation($input: SaveMarketplaceSearchInput!) {
        saveMarketplaceSearch(input: $input) {
          id
          name
          alertsEnabled
          createdAt
          zipCode
          radiusMiles
          serviceCategory
          ageRange
          language
          locationType
          urgency
          authorizationStatus
        }
      }
    ''';
    final result = await _graphql.query(mutation, variables: {
      'input': {
        'name': name,
        'alertsEnabled': alertsEnabled,
        'filters': {
          if (zipCode != null) 'zipCode': zipCode,
          if (radiusMiles != null) 'radiusMiles': radiusMiles,
          if (serviceCategory != null) 'serviceCategory': serviceCategory,
          if (ageRange != null) 'ageRange': ageRange,
          if (language != null) 'language': language,
          if (locationType != null) 'locationType': locationType,
          if (urgency != null) 'urgency': urgency,
          if (authorizationStatus != null)
            'authorizationStatus': authorizationStatus,
        },
      },
    });
    final row =
        result['data']?['saveMarketplaceSearch'] as Map<String, dynamic>;
    return MarketplaceSavedSearchModel(
      id: row['id'] as String,
      name: row['name'] as String,
      alertsEnabled: row['alertsEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(row['createdAt'] as String),
      zipCode: row['zipCode'] as String?,
      radiusMiles: (row['radiusMiles'] as num?)?.toDouble(),
      serviceCategory: row['serviceCategory'] as String?,
      ageRange: row['ageRange'] as String?,
      language: row['language'] as String?,
      locationType: row['locationType'] as String?,
      urgency: row['urgency'] as String?,
      authorizationStatus: row['authorizationStatus'] as String?,
    );
  }

  Future<void> deleteSavedSearch(String savedSearchId) async {
    const mutation = r'''
      mutation($id: ID!) {
        deleteMarketplaceSavedSearch(savedSearchId: $id)
      }
    ''';
    await _graphql.query(mutation, variables: {'id': savedSearchId});
  }

  Future<void> setSavedSearchAlerts({
    required String savedSearchId,
    required bool alertsEnabled,
  }) async {
    const mutation = r'''
      mutation($input: SetMarketplaceSavedSearchAlertsInput!) {
        setMarketplaceSavedSearchAlerts(input: $input) {
          id
        }
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'savedSearchId': savedSearchId,
        'alertsEnabled': alertsEnabled,
      },
    });
  }

  Future<void> reportListing({
    required String marketplaceRequestId,
    required String reason,
    String? details,
  }) async {
    await _api.post(
      '/marketplace-requests/$marketplaceRequestId/report',
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }

  Future<List<MarketplaceConsentModel>> fetchConsentHistory(
    String marketplaceRequestId,
  ) async {
    const query = r'''
      query($id: ID!) {
        marketplaceConsentHistory(marketplaceRequestId: $id) {
          id
          consentType
          consentTextVersion
          granted
          revokedAt
          createdAt
          provider {
            id
            displayName
            accountType
          }
        }
      }
    ''';
    final result = await _graphql.query(query, variables: {'id': marketplaceRequestId});
    final list =
        result['data']?['marketplaceConsentHistory'] as List<dynamic>? ?? [];
    return list.map((e) {
      final row = e as Map<String, dynamic>;
      final provider = row['provider'] as Map<String, dynamic>?;
      return MarketplaceConsentModel(
        id: row['id'] as String,
        consentType: row['consentType'] as String,
        consentTextVersion: row['consentTextVersion'] as String,
        granted: row['granted'] as bool? ?? false,
        revokedAt: row['revokedAt'] != null
            ? DateTime.parse(row['revokedAt'] as String)
            : null,
        createdAt: DateTime.parse(row['createdAt'] as String),
        providerId: provider?['id'] as String?,
        providerName: provider?['displayName'] as String?,
        providerAccountType: provider?['accountType'] as String?,
      );
    }).toList();
  }

  Future<void> revokeShareConsent({
    required String marketplaceRequestId,
    required String providerProfileId,
  }) async {
    const mutation = r'''
      mutation($input: RevokeMarketplaceConsentInput!) {
        revokeMarketplaceShareConsent(input: $input)
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'marketplaceRequestId': marketplaceRequestId,
        'providerProfileId': providerProfileId,
      },
    });
  }

  Future<AuthorizedChildDetailsModel?> fetchAuthorizedChildDetails(
    String marketplaceRequestId,
  ) async {
    const query = r'''
      query($id: ID!) {
        authorizedMarketplaceChildDetails(marketplaceRequestId: $id) {
          childId
          firstName
          lastName
          zipCode
          city
          state
          primaryLanguage
          parentName
          parentEmail
          parentPhone
          marketplaceRequestId
          anonymousPublicId
          sharedDocuments {
            id
            title
            fileName
            type
            uploadedAt
          }
        }
      }
    ''';
    final result = await _graphql.query(query, variables: {'id': marketplaceRequestId});
    final row =
        result['data']?['authorizedMarketplaceChildDetails'] as Map<String, dynamic>?;
    if (row == null) return null;
    final docs =
        (row['sharedDocuments'] as List<dynamic>?)
            ?.map((e) {
              final doc = e as Map<String, dynamic>;
              return MarketplaceSharedDocumentModel(
                id: doc['id'] as String,
                title: doc['title'] as String,
                fileName: doc['fileName'] as String,
                type: doc['type'] as String? ?? 'OTHER',
                uploadedAt: DateTime.parse(doc['uploadedAt'] as String),
              );
            })
            .toList() ??
        const [];
    return AuthorizedChildDetailsModel(
      childId: row['childId'] as String,
      firstName: row['firstName'] as String,
      lastName: row['lastName'] as String,
      zipCode: row['zipCode'] as String,
      city: row['city'] as String?,
      state: row['state'] as String?,
      primaryLanguage: row['primaryLanguage'] as String?,
      parentName: row['parentName'] as String,
      parentEmail: row['parentEmail'] as String?,
      parentPhone: row['parentPhone'] as String?,
      marketplaceRequestId: row['marketplaceRequestId'] as String,
      anonymousPublicId: row['anonymousPublicId'] as String,
      sharedDocuments: docs,
    );
  }

  Future<void> grantShareConsent({
    required String marketplaceRequestId,
    required String providerProfileId,
    List<String> documentIds = const [],
  }) async {
    const mutation = r'''
      mutation($input: GrantMarketplaceShareConsentInput!) {
        grantMarketplaceShareConsent(input: $input)
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'marketplaceRequestId': marketplaceRequestId,
        'providerProfileId': providerProfileId,
        if (documentIds.isNotEmpty) 'documentIds': documentIds,
      },
    });
  }

  MarketplaceRequestModel _mapRequest(Map<String, dynamic> row) {
    return MarketplaceRequestModel(
      id: row['id'] as String,
      anonymousPublicId: row['anonymousPublicId'] as String,
      serviceAreaLabel: row['serviceAreaLabel'] as String,
      ageRangeLabel: row['ageRangeLabel'] as String,
      serviceCategories: (row['serviceCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      concernTags: (row['concernTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      locationType: row['locationType'] as String? ?? 'HOME',
      authorizationStatusLabel:
          row['authorizationStatusLabel'] as String? ?? '',
      urgency: row['urgency'] as String? ?? 'ROUTINE',
      status: row['status'] as String? ?? 'ACTIVE',
      languagePreference: row['languagePreference'] as String?,
      publicDescription: row['publicDescription'] as String?,
      distanceMiles: (row['distanceMiles'] as num?)?.toDouble(),
      mapPinLat: (row['mapPinLat'] as num?)?.toDouble(),
      mapPinLng: (row['mapPinLng'] as num?)?.toDouble(),
      interestCount: row['interestCount'] as int? ?? 0,
      pendingInterestCount: row['pendingInterestCount'] as int? ?? 0,
      matchScore: (row['matchScore'] as num?)?.toDouble(),
      childId: row['childId'] as String?,
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(
    ref.watch(graphqlClientProvider),
    ref.watch(apiClientProvider),
  );
});

final parentMarketplaceRequestsProvider =
    FutureProvider.autoDispose<List<MarketplaceRequestModel>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).fetchMyRequests();
});

final providerMarketplaceProfileProvider =
    FutureProvider<ProviderMarketplaceProfileModel?>((ref) {
  return ref.watch(marketplaceRepositoryProvider).fetchProviderProfile();
});
