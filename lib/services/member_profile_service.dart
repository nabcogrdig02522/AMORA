import 'package:supabase_flutter/supabase_flutter.dart';

class MemberProfileService {
  MemberProfileService(this._db);
  final SupabaseClient _db;

  String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AuthException('Please sign in first.');
    return id;
  }

  Future<void> saveProfile({
    required String displayName,
    required String city,
    required String bio,
    required String relationshipGoal,
    required String gender,
    required List<String> interests,
    required List<String> values,
    required List<String> lifestyles,
    required int minAge,
    required int maxAge,
    required List<String> preferredGenders,
    required List<String> preferredGoals,
    required int maxDistanceKm,
  }) async {
    final id = _userId;
    await _db.from('profiles').upsert({
      'id': id,
      'display_name': displayName.trim(),
      'city': city.trim(),
      'bio': bio.trim(),
      'relationship_goal': relationshipGoal,
      'gender': gender,
    });

    // Replace the member's declared compatibility attributes in sequence.
    // These separate requests are not a database transaction; retry if one fails.
    await _replaceSet('member_interests', 'interest', interests, id);
    await _replaceSet('member_values', 'value_key', values, id);
    await _replaceSet('member_lifestyles', 'lifestyle_key', lifestyles, id);

    await _db.from('member_preferences').upsert({
      'user_id': id,
      'min_age': minAge,
      'max_age': maxAge,
      'preferred_genders': preferredGenders,
      'preferred_goals': preferredGoals,
      'max_distance_km': maxDistanceKm,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _replaceSet(
    String table,
    String column,
    List<String> values,
    String userId,
  ) async {
    await _db.from(table).delete().eq('user_id', userId);
    if (values.isEmpty) return;
    await _db.from(table).insert(values
        .map((value) => {'user_id': userId, column: value})
        .toList());
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final id = _userId;
    final profile = await _db.from('profiles').select(
      'id, display_name, city, bio, relationship_goal, gender',
    ).eq('id', id).maybeSingle();
    if (profile == null) return null;

    final interests = await _db.from('member_interests').select('interest').eq('user_id', id);
    final values = await _db.from('member_values').select('value_key').eq('user_id', id);
    final lifestyles = await _db.from('member_lifestyles').select('lifestyle_key').eq('user_id', id);
    final preferences = await _db.from('member_preferences').select().eq('user_id', id).maybeSingle();

    return {
      ...profile,
      'interests': interests.map((r) => r['interest'] as String).toList(),
      'values': values.map((r) => r['value_key'] as String).toList(),
      'lifestyles': lifestyles.map((r) => r['lifestyle_key'] as String).toList(),
      'preferences': preferences,
    };
  }
}
