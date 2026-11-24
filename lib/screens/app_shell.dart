import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'discovery_screen.dart';
import 'profile_screen.dart';
import 'likes_screen.dart';
import 'subscription_screen.dart';
import 'region_settings_screen.dart';
import 'trust_safety_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int index = 0;
  final pages = const [DiscoveryScreen(), LikesScreen(), ProfileScreen(), SubscriptionScreen(), RegionSettingsScreen()];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AMORA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF7B2348))),
      actions: [
        IconButton(tooltip: 'Trust & safety', icon: const Icon(Icons.shield_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrustSafetyScreen()))),
        IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
      ],
    ),
    body: pages[index],
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
        NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Matches'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Plans'),
        NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Region'),
      ],
    ),
  );
}
