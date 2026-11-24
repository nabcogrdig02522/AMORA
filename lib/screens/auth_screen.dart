import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();
  DateTime? dateOfBirth;
  bool busy = false;
  bool creatingAccount = false;
  String? message;

  Future<void> submit({required bool signUp}) async {
    if (signUp) {
      final dob = dateOfBirth;
      final adultCutoff = DateTime(DateTime.now().year - 18, DateTime.now().month, DateTime.now().day);
      if (displayName.text.trim().isEmpty || dob == null || dob.isAfter(adultCutoff)) {
        setState(() => message = 'Enter a display name and confirm that you are at least 18 years old.');
        return;
      }
    }
    if (!email.text.contains('@') || password.text.length < 8) {
      setState(() => message = 'Enter a valid email address and a password of at least 8 characters.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (signUp) {
        final dob = dateOfBirth!;
        await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {
            'display_name': displayName.text.trim(),
            'date_of_birth': '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
            'gender': 'Prefer to discuss',
          },
        );
        message = 'Account created. Check your email if confirmation is enabled, then sign in.';
        creatingAccount = false;
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Unable to complete this request. Please try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth (18+ only)',
    );
    if (selected != null) setState(() => dateOfBirth = selected);
  }

  @override
  void dispose() { email.dispose(); password.dispose(); displayName.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.favorite, size: 58, color: Color(0xFF7B2348)),
          const SizedBox(height: 12),
          const Text('AMORA', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: 6),
          const Text('Meaningful connections begin here.', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Sign in')), ButtonSegment(value: true, label: Text('Create account'))],
            selected: {creatingAccount},
            onSelectionChanged: busy ? null : (v) => setState(() { creatingAccount = v.first; message = null; }),
          ),
          if (creatingAccount) ...[
            const SizedBox(height: 16),
            TextField(controller: displayName, textCapitalization: TextCapitalization.words, maxLength: 60, decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseDob,
              icon: const Icon(Icons.cake_outlined),
              label: Text(dateOfBirth == null ? 'Select date of birth (18+)' : 'Date of birth: ${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}'),
            ),
            const SizedBox(height: 10),
          ],
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Password (minimum 8 characters)', border: OutlineInputBorder())),
          if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : () => submit(signUp: creatingAccount), child: Text(busy ? 'Please wait…' : creatingAccount ? 'Create account' : 'Sign in')),
          const SizedBox(height: 12),
          const Text('AMORA is intended for adults aged 18 and above.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      )),
    ))),
  );
}
