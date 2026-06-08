import '../../../core/network/graphql_client.dart';

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.description,
    this.paidAt,
  });

  final String id;
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime? paidAt;
  final DateTime createdAt;

  bool get isPaid => status == 'SUCCEEDED';
}

class PaymentsRepository {
  PaymentsRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _paymentsQuery = r'''
    query MyPayments {
      myPayments {
        id
        amount
        currency
        status
        description
        paidAt
        createdAt
      }
    }
  ''';

  static const _createPaymentMutation = r'''
    mutation CreatePayment($input: CreatePaymentInput!) {
      createPayment(input: $input) {
        payment { id amount status description }
        stripeConfigured
      }
    }
  ''';

  static const _confirmDemoMutation = r'''
    mutation ConfirmDemo($paymentId: ID!) {
      confirmPaymentDemo(paymentId: $paymentId) {
        id
        status
      }
    }
  ''';

  Future<List<PaymentModel>> fetchPayments() async {
    final result = await _graphql.query(_paymentsQuery);
    final list = result['data']?['myPayments'] as List<dynamic>? ?? [];
    return list.map(_mapPayment).toList();
  }

  Future<PaymentModel> createPayment({
    required int amountCents,
    String? description,
  }) async {
    final result = await _graphql.query(
      _createPaymentMutation,
      variables: {
        'input': {'amountCents': amountCents, 'description': ?description},
      },
    );
    final e =
        result['data']?['createPayment']?['payment'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Payment creation failed');
    return _mapPayment(e);
  }

  Future<void> confirmPaymentDemo(String paymentId) async {
    await _graphql.query(
      _confirmDemoMutation,
      variables: {'paymentId': paymentId},
    );
  }

  PaymentModel _mapPayment(dynamic e) {
    return PaymentModel(
      id: e['id'] as String,
      amount: (e['amount'] as num).toDouble(),
      currency: e['currency'] as String? ?? 'USD',
      status: e['status'] as String? ?? 'PENDING',
      description: e['description'] as String?,
      paidAt: DateTime.tryParse(e['paidAt'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
