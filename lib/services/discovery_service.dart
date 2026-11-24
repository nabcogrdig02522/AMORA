import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoveryService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> discover({int limit = 20}) async {
    final rows = await _db.rpc('discover_profiles', params: {'limit_count': limit});
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> like(String profileId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Please sign in.');
    await _db.from('likes').upsert({
      'liker_id': userId,
      'liked_id': profileId,
    }, onConflict: 'liker_id,liked_id');
  }
}
