import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrustSafetyService {
  TrustSafetyService(this.client);
  final SupabaseClient client;
  String get _uid => client.auth.currentUser!.id;

  Future<void> sendPhoneOtp(String phone) async {
    await client.auth.updateUser(UserAttributes(phone: phone.trim()));
  }

  Future<void> verifyPhoneOtp(String phone, String token) async {
    await client.auth.verifyOTP(phone: phone.trim(), token: token.trim(), type: OtpType.phoneChange);
  }

  Future<void> submitSelfie(XFile image, {required bool consent}) async {
    if (!consent) throw Exception('Consent is required before submitting a verification image.');
    final ext = image.name.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$_uid/${DateTime.now().toUtc().microsecondsSinceEpoch}.$ext';
    await client.storage.from('amora-verification').upload(
      path, File(image.path), fileOptions: FileOptions(contentType: contentType, upsert: false));
    try {
      await client.from('verification_requests').insert({
        'user_id': _uid,
        'verification_type': 'selfie',
        'status': 'pending',
        'private_object_path': path,
        'consented_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      await client.storage.from('amora-verification').remove([path]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> myVerificationRequests() async {
    final rows = await client.from('verification_requests').select(
      'id, verification_type, status, reviewer_note, created_at, reviewed_at')
      .eq('user_id', _uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> reportMember({required String targetUserId, required String category, String? description}) async {
    await client.from('member_reports').insert({
      'reporter_id': _uid, 'reported_user_id': targetUserId,
      'category': category, 'description': description?.trim().isEmpty == true ? null : description?.trim(),
    });
  }

  Future<void> blockMember(String targetUserId) async {
    await client.rpc('block_member', params: {'p_target_user_id': targetUserId});
  }

  Future<void> requestAccountDeletion({String? reason}) async {
    await client.from('account_deletion_requests').insert({
      'user_id': _uid,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
    });
  }
}
