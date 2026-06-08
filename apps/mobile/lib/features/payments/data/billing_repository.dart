import '../../../core/network/graphql_client.dart';
import 'payments_repository.dart';

class DisputeModel {
  const DisputeModel({
    required this.id,
    required this.status,
    required this.reason,
    this.paymentId,
    this.resolution,
  });

  final String id;
  final String status;
  final String reason;
  final String? paymentId;
  final String? resolution;
}

class PayoutModel {
  const PayoutModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    this.paidAt,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? paidAt;
}

class PaymentCreateResult {
  const PaymentCreateResult({
    required this.payment,
    this.checkoutUrl,
    this.stripeConfigured = false,
  });

  final PaymentModel payment;
  final String? checkoutUrl;
  final bool stripeConfigured;
}

class BillingRepository {
  BillingRepository(this._graphql);

  final GraphqlClient _graphql;

  Future<PaymentCreateResult> createPaymentWithCheckout({
    required int amountCents,
    String? description,
  }) async {
    final result = await _graphql.query(
      r'''
      mutation Create($input: CreatePaymentInput!) {
        createPayment(input: $input) {
          payment { id amount status description }
          checkoutUrl
          stripeConfigured
        }
      }
    ''',
      variables: {
        'input': {'amountCents': amountCents, 'description': ?description},
      },
    );
    final data = result['data']?['createPayment'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Payment creation failed');
    final p = data['payment'] as Map<String, dynamic>;
    return PaymentCreateResult(
      payment: PaymentModel(
        id: p['id'] as String,
        amount: (p['amount'] as num).toDouble(),
        currency: 'USD',
        status: p['status'] as String? ?? 'PENDING',
        description: p['description'] as String?,
        createdAt: DateTime.now(),
      ),
      checkoutUrl: data['checkoutUrl'] as String?,
      stripeConfigured: data['stripeConfigured'] as bool? ?? false,
    );
  }

  Future<void> syncPayment(String paymentId) async {
    await _graphql.query(
      r'''
      mutation Sync($id: ID!) {
        syncPaymentStatus(paymentId: $id) { id status }
      }
    ''',
      variables: {'id': paymentId},
    );
  }

  Future<void> openDispute({
    required String paymentId,
    required String reason,
  }) async {
    await _graphql.query(
      r'''
      mutation Dispute($input: OpenPaymentDisputeInput!) {
        openPaymentDispute(input: $input) { id }
      }
    ''',
      variables: {
        'input': {'paymentId': paymentId, 'reason': reason},
      },
    );
  }

  Future<List<DisputeModel>> fetchMyDisputes() async {
    final result = await _graphql.query(r'''
      query { myPaymentDisputes { id status reason paymentId resolution } }
    ''');
    final list = result['data']?['myPaymentDisputes'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => DisputeModel(
            id: e['id'] as String,
            status: e['status'] as String? ?? '',
            reason: e['reason'] as String? ?? '',
            paymentId: e['paymentId'] as String?,
            resolution: e['resolution'] as String?,
          ),
        )
        .toList();
  }

  Future<List<PayoutModel>> fetchTherapistPayouts() async {
    final result = await _graphql.query(r'''
      query {
        myTherapistPayouts {
          id amount status periodStart periodEnd paidAt
        }
      }
    ''');
    final list = result['data']?['myTherapistPayouts'] as List<dynamic>? ?? [];
    return list.map(_mapPayout).toList();
  }

  Future<List<DisputeModel>> fetchAdminDisputes() async {
    final result = await _graphql.query(r'''
      query { adminDisputes { id status reason paymentId resolution } }
    ''');
    final list = result['data']?['adminDisputes'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => DisputeModel(
            id: e['id'] as String,
            status: e['status'] as String? ?? '',
            reason: e['reason'] as String? ?? '',
            paymentId: e['paymentId'] as String?,
            resolution: e['resolution'] as String?,
          ),
        )
        .toList();
  }

  Future<List<PayoutModel>> fetchAdminPayouts() async {
    final result = await _graphql.query(r'''
      query {
        adminPayouts { id amount status periodStart periodEnd paidAt }
      }
    ''');
    final list = result['data']?['adminPayouts'] as List<dynamic>? ?? [];
    return list.map(_mapPayout).toList();
  }

  Future<void> resolveDispute(String id, String resolution) async {
    await _graphql.query(
      r'''
      mutation Resolve($id: ID!, $resolution: String!) {
        resolvePaymentDispute(disputeId: $id, resolution: $resolution) { id }
      }
    ''',
      variables: {'id': id, 'resolution': resolution},
    );
  }

  Future<void> markPayoutPaid(String payoutId) async {
    await _graphql.query(
      r'''
      mutation Mark($id: ID!) {
        markPayoutPaid(payoutId: $id) { id }
      }
    ''',
      variables: {'id': payoutId},
    );
  }

  PayoutModel _mapPayout(dynamic e) {
    return PayoutModel(
      id: e['id'] as String,
      amount: (e['amount'] as num).toDouble(),
      status: e['status'] as String? ?? '',
      periodStart: DateTime.parse(e['periodStart'] as String),
      periodEnd: DateTime.parse(e['periodEnd'] as String),
      paidAt: DateTime.tryParse(e['paidAt'] as String? ?? ''),
    );
  }
}
