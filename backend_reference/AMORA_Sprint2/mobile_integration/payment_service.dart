// Add url_launcher to pubspec.yaml before using this helper:
// url_launcher: ^6.3.1
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AmoraPaymentService {
  final SupabaseClient supabase;
  AmoraPaymentService(this.supabase);

  Future<void> startCheckout(String planCode) async {
    final response = await supabase.functions.invoke(
      'create-payment',
      body: {'plan_code': planCode},
    );
    if (response.status != 200) {
      throw Exception('Could not start checkout');
    }
    final data = Map<String, dynamic>.from(response.data);
    final uri = Uri.parse(data['authorization_url'] as String);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open secure payment checkout');
    }
    // IMPORTANT: Do not activate membership from the redirect.
    // Refresh subscriptions from Supabase after webhook processing.
  }
}
