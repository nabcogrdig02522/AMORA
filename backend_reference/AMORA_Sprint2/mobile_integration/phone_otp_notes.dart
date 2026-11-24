// Supabase Auth phone OTP flow. Configure an SMS provider in Supabase first.
// Store phone numbers privately in Auth; never expose them in public profile data.
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> requestPhoneCode(SupabaseClient supabase, String e164Phone) async {
  await supabase.auth.signInWithOtp(phone: e164Phone);
}

Future<void> verifyPhoneCode(
  SupabaseClient supabase, String e164Phone, String smsCode,
) async {
  await supabase.auth.verifyOTP(
    phone: e164Phone,
    token: smsCode,
    type: OtpType.sms,
  );
}
