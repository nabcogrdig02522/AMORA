import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/trust_safety_service.dart';

class TrustSafetyScreen extends StatefulWidget {
  const TrustSafetyScreen({super.key});
  @override
  State<TrustSafetyScreen> createState() => _TrustSafetyScreenState();
}

class _TrustSafetyScreenState extends State<TrustSafetyScreen> {
  final _service = TrustSafetyService(Supabase.instance.client);
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _deletionReason = TextEditingController();
  final _targetUserId = TextEditingController();
  final _reportDescription = TextEditingController();
  String _reportCategory = 'fake_profile';
  bool _sentOtp = false;
  bool _consent = false;
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() { _busy = true; _message = null; });
    try { await action(); _message = success; }
    catch (e) { _message = 'Could not complete this action: $e'; }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _pickSelfie() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 1600);
    if (image == null || !mounted) return;
    await _run(() => _service.submitSelfie(image, consent: _consent), 'Selfie submitted for manual review. This is not an automated identity or liveness check.');
  }

  @override
  void dispose() { _phone.dispose(); _otp.dispose(); _deletionReason.dispose(); _targetUserId.dispose(); _reportDescription.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Trust, safety & privacy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('Keep your account secure and help us maintain a respectful community.'),
    const SizedBox(height: 20),
    _section('Phone verification', 'Verify that you control a mobile number. Configure an SMS provider in Supabase Auth before use.'),
    TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number with country code', hintText: '+233…', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    if (!_sentOtp) FilledButton(onPressed: _busy ? null : () async { await _run(() async { await _service.sendPhoneOtp(_phone.text); _sentOtp = true; }, 'Verification code sent.'); if (mounted) setState(() {}); }, child: const Text('Send verification code'))
    else ...[
      TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SMS code', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton(onPressed: _busy ? null : () => _run(() => _service.verifyPhoneOtp(_phone.text, _otp.text), 'Phone number verified.'), child: const Text('Verify phone')),
    ],
    const Divider(height: 32),
    _section('Selfie review', 'Submit a selfie for a human moderator. No facial recognition, liveness detection or identity confirmation is performed by this starter.'),
    CheckboxListTile(value: _consent, onChanged: (v) => setState(() => _consent = v ?? false), contentPadding: EdgeInsets.zero, title: const Text('I consent to AMORA securely storing this image for verification review and understand it may be accessed by authorised moderators.')),
    OutlinedButton.icon(onPressed: _busy || !_consent ? null : _pickSelfie, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Take and submit selfie')),
    const Divider(height: 32),
    _section('Report or block a member', 'Enter the member profile UUID. Blocking removes any existing match and conversation access. Use the report option to alert moderators.'),
    TextField(controller: _targetUserId, decoration: const InputDecoration(labelText: 'Member profile ID', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(value: _reportCategory, decoration: const InputDecoration(labelText: 'Report reason', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'fake_profile', child: Text('Fake profile')), DropdownMenuItem(value: 'harassment', child: Text('Harassment')), DropdownMenuItem(value: 'scam_or_spam', child: Text('Scam or spam')), DropdownMenuItem(value: 'underage_safety', child: Text('Underage safety concern')), DropdownMenuItem(value: 'inappropriate_content', child: Text('Inappropriate content')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (v) => setState(() => _reportCategory = v ?? 'fake_profile')),
    const SizedBox(height: 8),
    TextField(controller: _reportDescription, maxLength: 2000, maxLines: 2, decoration: const InputDecoration(labelText: 'Optional details', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    OutlinedButton(onPressed: _busy ? null : () => _run(() => _service.reportMember(targetUserId: _targetUserId.text.trim(), category: _reportCategory, description: _reportDescription.text), 'Report submitted to the moderation queue.'), child: const Text('Submit report')),
    TextButton.icon(onPressed: _busy ? null : () async { final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Block this member?'), content: const Text('You will no longer see each other in discovery. Existing match and conversation access will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block member'))])); if (ok == true) await _run(() => _service.blockMember(_targetUserId.text.trim()), 'Member blocked.'); }, icon: const Icon(Icons.block), label: const Text('Block member')),
    const Divider(height: 32),
    _section('Account deletion', 'Request deletion of your account. This submits a request for secure processing; it does not immediately erase your account or messages.'),
    TextField(controller: _deletionReason, maxLength: 1000, maxLines: 2, decoration: const InputDecoration(labelText: 'Optional reason', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: _busy ? null : () => _run(() => _service.requestAccountDeletion(reason: _deletionReason.text), 'Deletion request submitted for review.'), icon: const Icon(Icons.delete_outline), label: const Text('Request account deletion')),
    if (_message != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_message!)),
    if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
  ]);

  Widget _section(String title, String subtitle) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.black54))]));
}
