import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/help_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final s = HelpService();
  bool admin = false;
  Future<List<Map<String, dynamic>>>? _adminTicketsFuture;

  @override
  void initState() {
    super.initState();
    s.admin().then((v) {
      if (!mounted) return;
      setState(() {
        admin = v;
        if (v) _adminTicketsFuture = s.adminTickets();
      });
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => setState(() {
                _adminTicketsFuture = s.adminTickets();
              }),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      floatingActionButton: admin ? null : FloatingActionButton(
        onPressed: newTicket,
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: admin
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: _adminTicketsFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting ||
                    _adminTicketsFuture == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Ошибка загрузки обращений: ${snap.error}'),
                  );
                }
                final tickets = snap.data ?? [];
                if (tickets.isEmpty) {
                  return const Center(child: Text('Обращений пока нет'));
                }
                return ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (_, i) {
                    final d = tickets[i];
                    final open = d['status'] == 'open';
                    final isAppeal = d['type'] == 'block_appeal';
                    return ListTile(
                      leading: Icon(
                        isAppeal
                            ? Icons.gavel_outlined
                            : (open
                                ? Icons.mark_email_unread_outlined
                                : Icons.mark_email_read_outlined),
                      ),
                      title: Text(
                        isAppeal
                            ? '⚖️ Апелляция на блокировку'
                            : (d['subject'] ?? 'Без темы').toString(),
                      ),
                      subtitle: Text(
                        d['lastMessage']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(open ? 'Открыт' : 'Закрыт'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketView(
                            id: d['id'].toString(),
                            admin: true,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          setState(() {
                            _adminTicketsFuture = s.adminTickets();
                          });
                        }
                      }),
                    );
                  },
                );
              },
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: s.mine(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Обращений пока нет'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final open = d['status'] == 'open';
                    return ListTile(
                      leading: Icon(
                        open
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                      ),
                      title: Text(d['subject'] ?? 'Без темы'),
                      subtitle: Text(
                        d['lastMessage'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(open ? 'Открыт' : 'Закрыт'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketView(id: docs[i].id, admin: false),
                        ),
                      ),
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

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

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
                  if (v == 'warn' || v == 'block24' || v == 'blockPermanent' || v == 'unblock' || v == 'penalty') {
                    final ownerUid = snap.data?.data()?['ownerUid']?.toString();
                    if (ownerUid == null || ownerUid.isEmpty) return;

                    if (v == 'penalty') {
                      final amountController = TextEditingController();
                      final reasonController = TextEditingController();
                      final result = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('🌟 Списание ядер 🌟'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Количество ядер',
                                  hintText: '70',
                                  prefixText: '🟣 ',
                                ),
                              ),
                              TextField(
                                controller: reasonController,
                                decoration: const InputDecoration(labelText: 'Причина'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final amount = int.tryParse(amountController.text.trim());
                                final reason = reasonController.text.trim();
                                if (amount != null && amount > 0 && reason.isNotEmpty) {
                                  Navigator.pop(context, {'amount': amount, 'reason': reason});
                                }
                              },
                              child: const Text('Продолжить'),
                            ),
                          ],
                        ),
                      );
                      amountController.dispose();
                      reasonController.dispose();
                      if (result == null) return;

                      final amount = result['amount'] as int;
                      final reason = result['reason'] as String;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('🟣 Списать $amount ядер?'),
                          content: Text('Будет списано 🟣 $amount.\n\nПричина: $reason'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Списать $amount 🟣'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      try {
                        await s.penalizeUser(ownerUid, amount, reason);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Штраф применён')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                      return;
                    }

                    final actionTitle = v == 'warn'
                        ? 'Предупредить пользователя?'
                        : v == 'block24'
                            ? 'Заморозить на 24 часа?'
                            : v == 'blockPermanent'
                                ? 'Заблокировать навсегда?'
                                : 'Снять блокировку?';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(actionTitle),
                        content: const Text(
                          'Проверь действие перед применением. После подтверждения оно будет отправлено на сервер.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Подтвердить'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;

                    try {
                      if (v == 'warn') {
                        await s.warnUser(ownerUid, 'Нарушение правил поддержки');
                      } else if (v == 'block24') {
                        await s.blockUser(ownerUid, reason: 'Нарушение правил поддержки', hours: 24);
                      } else if (v == 'blockPermanent') {
                        await s.blockUser(ownerUid, reason: 'Систематические или серьёзные нарушения', permanent: true);
                      } else {
                        await s.unblockUser(ownerUid);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Модерация применена')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (open) const PopupMenuItem(value: 'finish', child: Text('Закрыть')),
                  if (!open) const PopupMenuItem(value: 'reopen', child: Text('Открыть снова')),
                  if (widget.admin) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'warn', child: Text('Предупредить')),
                    const PopupMenuItem(value: 'penalty', child: Text('Штраф ядрами')),
                    const PopupMenuItem(value: 'block24', child: Text('Заморозить на 24 часа')),
                    const PopupMenuItem(value: 'blockPermanent', child: Text('Заблокировать навсегда')),
                    const PopupMenuItem(value: 'unblock', child: Text('Снять блокировку')),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: s.db.collection('tickets').doc(widget.id).snapshots(),
        builder: (context, ticketSnap) {
          final ticketData = ticketSnap.data?.data();
          final open = ticketData?['status'] == 'open';

          return Column(
            children: [
              if (ticketData != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(
                        open
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        open ? 'Обращение открыто' : 'Обращение закрыто',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder(
                  stream: s.messages(widget.id),
                  builder: (_, AsyncSnapshot snap) {
                    final docs = snap.data?.docs ?? [];
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (docs.isEmpty) {
                      return const Center(child: Text('Сообщений пока нет'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final mine = d['senderUid'] == s.uid;
                        return Align(
                          alignment:
                              mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(d['text'] ?? ''),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: c,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    'Обращение закрыто. Откройте его снова, чтобы продолжить диалог.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
