import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || anonKey == null || url.contains('YOUR_PROJECT')) {
    runApp(const AmoraApp(configured: false));
    return;
  }
  await Supabase.initialize(url: url, anonKey: anonKey);
  runApp(const AmoraApp(configured: true));
}

class AmoraApp extends StatelessWidget {
  const AmoraApp({super.key, required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF7B2348);
    return MaterialApp(
      title: 'AMORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: wine),
        scaffoldBackgroundColor: const Color(0xFFFFF9FB),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: configured ? const AuthGate() : const SetupScreen(),
    );
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite, size: 64, color: Color(0xFF7B2348)),
          const SizedBox(height: 16),
          const Text('Welcome to AMORA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Your Flutter app has been created. Add your Supabase project URL and anon key to the local .env file to connect the backend.', textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const AuthScreen() : const AppShell();
      },
    );
  }
}
