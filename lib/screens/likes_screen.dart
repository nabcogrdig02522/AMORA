import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/match_service.dart';
import 'chat_screen.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});
  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  late final MatchService service;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    service = MatchService(Supabase.instance.client);
    future = service.conversations();
  }
  void refresh() => setState(() => future = service.conversations());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _empty('Could not load your matches. Apply the Sprint 4 database migration and check Supabase relationships.');
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return _empty('Your mutual matches will appear here. When two members like each other, AMORA creates a match.');
      return RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            final match = row['matches'] as Map<String, dynamic>? ?? {};
            final me = Supabase.instance.client.auth.currentUser?.id;
            final one = match['user_one'] as Map<String, dynamic>? ?? {};
            final two = match['user_two'] as Map<String, dynamic>? ?? {};
            final other = match['user_one_id'] == me ? two : one;
            final name = (other['display_name'] ?? 'Your match').toString();
            return ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFF1D7E2), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A')),
              title: Text(name),
              subtitle: Text((other['city'] ?? 'AMORA member').toString()),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: row['id'].toString(), title: name),
              )),
            );
          },
        ),
      );
    },
  );

  Widget _empty(String message) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.favorite, size: 48, color: Color(0xFF7B2348)),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: refresh, child: const Text('Refresh')),
    ]),
  ));
}
