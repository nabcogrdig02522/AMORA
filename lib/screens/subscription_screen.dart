import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final PaymentService service;
  late Future<Map<String, dynamic>?> subscription;
  late Future<List<Map<String, dynamic>>> history;
  late Future<List<MarketPlan>> plans;
  String? notice;
  String? startingPlan;

  @override
  void initState() {
    super.initState();
    service = PaymentService(Supabase.instance.client);
    _reload();
  }

  void _reload() {
    subscription = service.currentSubscription();
    history = service.paymentHistory();
    plans = service.availablePlans();
  }

  Future<void> _buy(MarketPlan plan) async {
    setState(() { startingPlan = plan.code; notice = null; });
    try {
      await service.startCheckout(plan.code);
      if (mounted) setState(() => notice = 'Secure checkout opened. Your membership activates only after the payment provider confirms payment.');
    } catch (_) {
      if (mounted) setState(() => notice = 'Checkout is unavailable. Confirm your market and payment configuration.');
    } finally {
      if (mounted) setState(() => startingPlan = null);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(dynamic amountMinor, dynamic currency) =>
    '${currency ?? ''} ${((amountMinor as num) / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Membership', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Core matchmaking remains available with Free membership. Paid plans depend on your selected market.'),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>?>(
        future: subscription,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
          if (snapshot.hasError) return const Text('Unable to retrieve membership status.');
          final row = snapshot.data;
          if (row == null) return const Card(child: ListTile(leading: Icon(Icons.person_outline), title: Text('Free membership'), subtitle: Text('No active paid subscription.')));
          return Card(child: ListTile(
            leading: const Icon(Icons.verified),
            title: Text('Active ${row['plan_code'].toString().toUpperCase()} membership'),
            subtitle: Text('Valid until ${_date(row['ends_at'])}'),
          ));
        },
      ),
      if (notice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(notice!)),
      const SizedBox(height: 8),
      const Text('Available plans in your market', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      FutureBuilder<List<MarketPlan>>(
        future: plans,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
          if (snapshot.hasError) return const Text('Could not load local plan prices. Apply the Sprint 8 migration.');
          final list = snapshot.data ?? [];
          if (list.isEmpty) return const Card(child: ListTile(
            leading: Icon(Icons.public),
            title: Text('Paid plans are not yet available in this market'),
            subtitle: Text('You can continue using AMORA Free while local payments are prepared.'),
          ));
          return Column(children: list.map((plan) {
            final title = switch (plan.code) {
              'plus' => 'AMORA Plus',
              'premium' => 'AMORA Premium',
              'elite' => 'AMORA Elite',
              _ => plan.code.toUpperCase(),
            };
            return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Valid for ${plan.days} days'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_money(plan.amountMinor, plan.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 30, child: TextButton(
                  onPressed: startingPlan == null ? () => _buy(plan) : null,
                  child: Text(startingPlan == plan.code ? 'Opening…' : 'Choose'),
                )),
              ]),
            ));
          }).toList());
        },
      ),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(
        'Prices are set by market configuration. A market will show paid plans only after its pricing and payment provider have been enabled by AMORA.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      )),
      const SizedBox(height: 12),
      const Text('Payment history', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: history,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
          if (snapshot.hasError) return const Text('Payment history is currently unavailable.');
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Text('No payment records yet.');
          return Column(children: rows.map((row) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${row['plan_code'].toString().toUpperCase()} • ${_money(row['amount_minor'], row['currency'])}'),
            subtitle: Text('${_date(row['created_at'])} • ${row['country_code']} • ${row['provider']}'),
            trailing: Text(row['status'].toString()),
          )).toList());
        },
      ),
    ]),
  );
}
