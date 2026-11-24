import 'package:supabase_flutter/supabase_flutter.dart';

class AmoraCompatibilityService {
  final SupabaseClient supabase;
  AmoraCompatibilityService(this.supabase);

  Future<List<Map<String, dynamic>>> discover({int limit = 20}) async {
    final rows = await supabase.rpc('discover_profiles', params: {
      'limit_count': limit.clamp(1, 50),
    });
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveInterests(List<String> interests) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('member_interests').delete().eq('user_id', uid);
    if (interests.isNotEmpty) {
      await supabase.from('member_interests').insert(
        interests.toSet().map((v) => {'user_id': uid, 'interest': v}).toList(),
      );
    }
  }

  Future<void> saveValues(List<String> values) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('member_values').delete().eq('user_id', uid);
    if (values.isNotEmpty) {
      await supabase.from('member_values').insert(
        values.toSet().map((v) => {'user_id': uid, 'value_key': v}).toList(),
      );
    }
  }

  Future<void> saveLifestyle(List<String> items) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('member_lifestyles').delete().eq('user_id', uid);
    if (items.isNotEmpty) {
      await supabase.from('member_lifestyles').insert(
        items.toSet().map((v) => {'user_id': uid, 'lifestyle_key': v}).toList(),
      );
    }
  }
}
