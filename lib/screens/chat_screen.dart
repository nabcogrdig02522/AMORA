import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/match_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.title});
  final String conversationId;
  final String title;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  late final MatchService service;
  final controller = TextEditingController();
  bool sending = false;
  @override
  void initState() { super.initState(); service = MatchService(Supabase.instance.client); }
  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> send() async {
    final text = controller.text;
    if (text.trim().isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await service.sendMessage(widget.conversationId, text);
      controller.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message could not be sent. Please try again.')));
    } finally { if (mounted) setState(() => sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: service.watchMessages(widget.conversationId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Unable to load messages. Check realtime and access policies.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final messages = snapshot.data!;
            if (messages.isEmpty) return const Center(child: Text('Say hello and start the conversation.'));
            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final row = messages[i];
                final mine = row['sender_id'] == me;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFF7B2348) : const Color(0xFFF1D7E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(row['body'].toString(), style: TextStyle(color: mine ? Colors.white : Colors.black87)),
                  ),
                );
              },
            );
          },
        )),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: controller,
              minLines: 1, maxLines: 4, maxLength: 4000,
              decoration: const InputDecoration(hintText: 'Write a message…', border: OutlineInputBorder(), counterText: ''),
              onSubmitted: (_) => send(),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            ),
          ]),
        )),
      ]),
    );
  }
}
