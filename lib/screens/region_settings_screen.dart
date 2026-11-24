import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../regional/regional_country.dart';

class RegionSettingsScreen extends StatefulWidget {
  const RegionSettingsScreen({super.key});
  @override
  State<RegionSettingsScreen> createState() => _RegionSettingsScreenState();
}

class _RegionSettingsScreenState extends State<RegionSettingsScreen> {
  final db = Supabase.instance.client;
  final cityController = TextEditingController();
  String countryCode = 'GH';
  bool crossBorder = false;
  bool loading = true;
  bool saving = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    cityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() { loading = false; notice = 'Sign in to manage your region.'; });
      return;
    }
    try {
      final profile = await db.from('profiles').select('country_code,city').eq('id', user.id).maybeSingle();
      final preferences = await db.from('member_regional_preferences')
          .select('cross_border_enabled').eq('user_id', user.id).maybeSingle();
      if (!mounted) return;
      setState(() {
        countryCode = (profile?['country_code'] as String?) ?? 'GH';
        cityController.text = (profile?['city'] as String?) ?? '';
        crossBorder = (preferences?['cross_border_enabled'] as bool?) ?? false;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { loading = false; notice = 'Could not load regional settings. Apply the West Africa migration and check your profile schema.'; });
    }
  }

  Future<void> _save() async {
    final user = db.auth.currentUser;
    if (user == null) return;
    setState(() { saving = true; notice = null; });
    try {
      await db.from('profiles').update({
        'country_code': countryCode,
        'city': cityController.text.trim(),
      }).eq('id', user.id);
      await db.from('member_regional_preferences').upsert({
        'user_id': user.id,
        'cross_border_enabled': crossBorder,
        'preferred_country_codes': <String>[],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      if (mounted) setState(() => notice = 'Regional preferences saved.');
    } catch (_) {
      if (mounted) setState(() => notice = 'Unable to save. Confirm the regional migration and RLS policies are applied.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final selected = AmoraMarkets.byCode(countryCode);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Your region', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Set your home country and city. Ghana is the only active pilot market; other country markets remain disabled until local launch approval.'),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        value: countryCode,
        decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
        items: AmoraMarkets.countries.map((c) => DropdownMenuItem<String>(value: c.code, enabled: c.code == 'GH', child: Text(c.code == 'GH' ? '${c.name} (${c.code}) — pilot' : '${c.name} (${c.code}) — coming soon'))).toList(),
        onChanged: (value) => setState(() => countryCode = value ?? 'GH'),
      ),
      const SizedBox(height: 12),
      TextField(controller: cityController, decoration: InputDecoration(
        labelText: 'City or town', hintText: 'e.g. ${selected.exampleCity}', border: const OutlineInputBorder(),
      )),
      const SizedBox(height: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Allow cross-border discovery'),
        subtitle: const Text('Cross-border discovery is mutual: you will only see members from another country if both of you have enabled it. You can turn this off at any time.'),
        value: crossBorder,
        onChanged: (value) => setState(() => crossBorder = value),
      ),
      const SizedBox(height: 8),
      Card(child: ListTile(
        leading: const Icon(Icons.public),
        title: Text('${selected.name} market'),
        subtitle: Text('Local currency: ${selected.currency}. Currency is shown as a market reference; payment availability depends on local integration.'),
      )),
      if (notice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(notice!)),
      FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving…' : 'Save regional settings')),
      const SizedBox(height: 16),
      const Text('Privacy note: cross-border discovery is an opt-in setting. Your exact location is not requested by this screen.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }
}
