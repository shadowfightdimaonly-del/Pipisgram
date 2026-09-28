import 'package:flutter/material.dart';
import '../services/help_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final s = HelpService();
  bool admin = false;

  @override
  void initState() {
    super.initState();
    s.admin().then((v) { if (mounted) setState(() => admin = v); });
  }

  Future<void> newTicket() async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новое обращение'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, decoration: const InputDecoration(labelText: 'Тема')),
          TextField(controller: b, minLines: 3, maxLines: 7, decoration: const InputDecoration(labelText: 'Сообщение')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (ok != true || a.text.trim().isEmpty || b.text.trim().isEmpty) return;
    final id = await s.create(a.text, b.text);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TicketView(id: id, admin: admin)));
  }

  @override
  Widget build(BuildContext context) {
    final stream = admin ? s.all() : s.mine();
    return Scaffold(
      appBar: AppBar(title: const Text('Поддержка')),
      floatingActionButton: admin ? null : FloatingActionButton(
        onPressed: newTicket, child: const Icon(Icons.add_comment_outlined)),
      body: StreamBuilder(
        stream: stream,
        builder: (_, AsyncSnapshot snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Обращений пока нет'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final open = d['status'] == 'open';
              return ListTile(
                leading: Icon(open ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined),
                title: Text(d['subject'] ?? 'Без темы'),
                subtitle: Text(d['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(open ? 'Открыт' : 'Закрыт'),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TicketView(id: docs[i].id, admin: admin))),
              );
            },
          );
        },
      ),
    );
  }
}

class TicketView extends StatefulWidget {
  final String id;
  final bool admin;
  const TicketView({super.key, required this.id, required this.admin});
  @override
  State<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends State<TicketView> {
  final s = HelpService();
  final c = TextEditingController();

  Future<void> send() async {
    if (c.text.trim().isEmpty) return;
    try {
      await s.send(widget.id, c.text);
      c.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> finish() async {
    final values = ['Решено', 'Не требует ответа', 'Спам', 'Нарушение правил', 'Другое'];
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final v in values) ListTile(title: Text(v), onTap: () => Navigator.pop(context, v))],
      )),
    );
    if (value != null) await s.close(widget.id, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обращение'),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: s.db.collection('tickets').doc(widget.id).snapshots(),
            builder: (_, snap) {
              final open = snap.data?.data()?['status'] == 'open';
              return PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'finish') await finish();
                  if (v == 'reopen') await s.reopen(widget.id);
                },
                itemBuilder: (_) => [
                  if (open) const PopupMenuItem(value: 'finish', child: Text('Закрыть')),
                  if (!open) const PopupMenuItem(value: 'reopen', child: Text('Открыть снова')),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder(
          stream: s.messages(widget.id),
          builder: (_, AsyncSnapshot snap) {
            final docs = snap.data?.docs ?? [];
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final mine = d['senderUid'] == s.uid;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(d['text'] ?? ''),
                  ),
                );
              },
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(controller: c, minLines: 1, maxLines: 5, decoration: const InputDecoration(hintText: 'Сообщение'))),
            IconButton(onPressed: send, icon: const Icon(Icons.send)),
          ]),
        ),
      ]),
    );
  }
}
