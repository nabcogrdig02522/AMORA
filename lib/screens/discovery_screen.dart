import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/discovery_service.dart';
import '../services/match_service.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}
class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final discovery = DiscoveryService();
  late final MatchService actions;
  late Future<List<Map<String, dynamic>>> future;
  bool busy = false;
  @override
  void initState() { super.initState(); actions = MatchService(Supabase.instance.client); future = discovery.discover(); }
  void refresh() => setState(() => future = discovery.discover());

  Future<void> act(Map<String, dynamic> profile, {required bool like}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (like) {
        await actions.like(profile['id'].toString());
      } else {
        await actions.pass(profile['id'].toString());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(like ? 'Like sent. If they like you too, you will match!' : 'Profile passed.')));
        refresh();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action could not be completed. Please try again.')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _notice('Discovery is not ready. Confirm that the Sprint 1 and Sprint 2 database migrations are applied.', onRetry: refresh);
      final profiles = snapshot.data ?? [];
      if (profiles.isEmpty) return _notice('No profiles to show right now. Complete your profile and check back soon.', onRetry: refresh);
      return RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: profiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = profiles[i];
            final name = (p['display_name'] ?? 'AMORA member').toString();
            final city = (p['city'] ?? '').toString();
            final country = (p['country_name'] ?? p['country_code'] ?? '').toString();
            final location = [city, country].where((v) => v.trim().isNotEmpty).join(', ');
            final bio = (p['bio'] ?? 'Looking to make a meaningful connection.').toString();
            final score = p['compatibility'];
            return Card(clipBehavior: Clip.antiAlias, child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 170, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF2DCE5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.person, size: 80, color: Color(0xFF7B2348))),
                const SizedBox(height: 14),
                Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(location.isEmpty ? 'West Africa' : location, style: const TextStyle(color: Colors.black54)),
                if (score != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Compatibility: ${(score as num).round()}%')),
                const SizedBox(height: 8),
                Text(bio),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => act(p, like: false),
                    icon: const Icon(Icons.close), label: const Text('Pass'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: busy ? null : () => act(p, like: true),
                    icon: const Icon(Icons.favorite), label: const Text('Like'),
                  ),
                ]),
              ]),
            ));
          },
        ),
      );
    },
  );

  Widget _notice(String text, {required VoidCallback onRetry}) => Center(child: Padding(
    padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.favorite_border, size: 48, color: Color(0xFF7B2348)),
      const SizedBox(height: 12), Text(text, textAlign: TextAlign.center),
      const SizedBox(height: 14), OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    ]),
  ));
}
