import 'package:supabase_flutter/supabase_flutter.dart';

class MatchService {
  MatchService(this.db);
  final SupabaseClient db;

  String get userId {
    final id = db.auth.currentUser?.id;
    if (id == null) throw const AuthException('Please sign in first.');
    return id;
  }

  Future<void> like(String profileId) async {
    await db.from('likes').upsert({
      'liker_id': userId,
      'liked_id': profileId,
    }, onConflict: 'liker_id,liked_id');
  }

  Future<void> pass(String profileId) async {
    await db.from('profile_passes').upsert({
      'passer_id': userId,
      'passed_id': profileId,
    }, onConflict: 'passer_id,passed_id');
  }

  Future<List<Map<String, dynamic>>> matches() async {
    final rows = await db.from('matches').select(
      'id,user_one_id,user_two_id,created_at'
    ).or('user_one_id.eq.$userId,user_two_id.eq.$userId')
      .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final rows = await db.from('conversations').select(
      'id,match_id,created_at,last_message_at,'
      'matches!inner(id,user_one_id,user_two_id,'
      'user_one:profiles!matches_user_one_id_fkey(id,display_name,photo_url,city),'
      'user_two:profiles!matches_user_two_id_fkey(id,display_name,photo_url,city))'
    ).order('last_message_at', ascending: false, nullsFirst: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final rows = await db.from('messages').select(
      'id,conversation_id,sender_id,body,created_at,read_at'
    ).eq('conversation_id', conversationId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty) return;
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'body': clean,
    });
    await db.from('conversations').update({
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return db.from('messages').stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.cast<Map<String, dynamic>>());
  }
}
