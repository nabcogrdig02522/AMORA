import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketPlan {
  const MarketPlan({required this.code, required this.amountMinor, required this.currency, required this.days});
  final String code;
  final int amountMinor;
  final String currency;
  final int days;

  double get amount => amountMinor / 100.0;
}

class PaymentService {
  PaymentService(this.db);
  final SupabaseClient db;

  Future<List<MarketPlan>> availablePlans() async {
    final user = db.auth.currentUser;
    if (user == null) return [];
    final profile = await db.from('profiles').select('country_code').eq('id', user.id).maybeSingle();
    final country = (profile?['country_code'] as String?) ?? 'GH';
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.from('market_plan_prices')
      .select('plan_code,amount_minor,currency_code,billing_days')
      .eq('country_code', country).eq('enabled', true)
      .lte('effective_from', now)
      .or('effective_to.is.null,effective_to.gt.$now')
      .order('effective_from', ascending: false);
    final seen = <String>{};
    final plans = <MarketPlan>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final code = row['plan_code'].toString();
      if (seen.add(code)) {
        plans.add(MarketPlan(
          code: code,
          amountMinor: (row['amount_minor'] as num).toInt(),
          currency: row['currency_code'].toString(),
          days: (row['billing_days'] as num).toInt(),
        ));
      }
    }
    return plans;
  }

  Future<void> startCheckout(String planCode) async {
    final response = await db.functions.invoke('create-payment', body: {'plan_code': planCode});
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Payment checkout could not be started.');
    }
    final data = response.data as Map<String, dynamic>;
    final rawUrl = data['authorization_url'] as String?;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https') throw Exception('Invalid secure checkout URL.');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open secure checkout.');
    }
  }

  Future<Map<String, dynamic>?> currentSubscription() async {
    final user = db.auth.currentUser;
    if (user == null) return null;
    final rows = await db.from('subscriptions').select('id,plan_code,status,starts_at,ends_at,created_at')
      .eq('user_id', user.id).eq('status', 'active')
      .order('ends_at', ascending: false).limit(1);
    if ((rows as List).isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
    if (end == null || end.isBefore(DateTime.now().toUtc())) return null;
    return row;
  }

  Future<List<Map<String, dynamic>>> paymentHistory() async {
    final user = db.auth.currentUser;
    if (user == null) return [];
    final rows = await db.from('payment_intents').select(
      'id,plan_code,amount_minor,currency,status,provider,created_at,country_code'
    ).eq('user_id', user.id).order('created_at', ascending: false).limit(30);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
