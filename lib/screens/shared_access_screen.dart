import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/horse.dart';
import '../services/firestore_service.dart';

class SharedAccessScreen extends StatefulWidget {
  final Horse horse;
  const SharedAccessScreen({super.key, required this.horse});
  @override
  State<SharedAccessScreen> createState() => _SharedAccessScreenState();
}

class _SharedAccessScreenState extends State<SharedAccessScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;
  Map<String, String> _sharedEmails = {};
  bool _loadingEmails = true;

  @override
  void initState() {
    super.initState();
    _loadSharedEmails();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSharedEmails() async {
    if (widget.horse.sharedWith.isEmpty) {
      setState(() => _loadingEmails = false);
      return;
    }
    final db = FirebaseFirestore.instance;
    final emails = <String, String>{};
    for (final uid in widget.horse.sharedWith) {
      try {
        final doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
          emails[uid] = doc.data()?['email'] ?? uid;
        } else {
          emails[uid] = uid;
        }
      } catch (_) {
        emails[uid] = uid;
      }
    }
    if (mounted) {
      setState(() {
        _sharedEmails = emails;
        _loadingEmails = false;
      });
    }
  }

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final fs = context.read<FirestoreService>();

    try {
      final targetUid = await fs.findUidByEmail(email);

      if (targetUid == null) {
        setState(() {
          _error = 'No NutriEquine account found for "$email".\n\n'
              'Ask them to:\n'
              '1. Install the NutriEquine app\n'
              '2. Create an account with this exact email\n'
              '3. Open the app at least once\n'
              '4. Then try inviting again';
        });
        return;
      }

      if (targetUid == fs.uid) {
        setState(
            () => _error = 'You cannot share a horse with yourself.');
        return;
      }

      if (widget.horse.sharedWith.contains(targetUid)) {
        setState(() => _error =
            '"$email" already has access to ${widget.horse.name}.');
        return;
      }

      await fs.shareHorseWithUser(widget.horse.id, targetUid);

      setState(() {
        _sharedEmails[targetUid] = email;
        _success =
            '✅ "${widget.horse.name}" is now shared with $email.\n'
            'They will see this horse the next time they open their app.';
        _emailCtrl.clear();
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeAccess(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove access?'),
        content:
            Text('Remove "$email" from ${widget.horse.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context
            .read<FirestoreService>()
            .removeSharedAccess(widget.horse.id, uid);
        setState(() {
          _sharedEmails.remove(uid);
          _success = 'Access removed for "$email".';
        });
      } catch (e) {
        setState(() => _error = 'Error removing access: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Team Access — ${widget.horse.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2F5233).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        const Color(0xFF2F5233).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How sharing works',
                      style:
                          TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    '1. The person must have a NutriEquine account\n'
                    '2. They must have opened the app at least once\n'
                    '3. Enter their exact email address below\n'
                    '4. They will see this horse in their Horses tab',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Invite by email',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(),
                      hintText: 'their@email.com',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _invite,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Invite'),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13)),
              ),
            ],

            if (_success != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.shade200),
                ),
                child: Text(_success!,
                    style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 13)),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Text('Current team',
                    style:
                        Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${_sharedEmails.length}'),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loadingEmails)
              const Center(child: CircularProgressIndicator())
            else if (_sharedEmails.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No team members yet. Invite someone above.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._sharedEmails.entries.map((entry) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2F5233)
                            .withOpacity(0.15),
                        child: Text(
                          entry.value.isNotEmpty
                              ? entry.value[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF2F5233),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(entry.value),
                      subtitle: const Text('Team member'),
                      trailing: IconButton(
                        icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red),
                        tooltip: 'Remove access',
                        onPressed: () => _removeAccess(
                            entry.key, entry.value),
                      ),
                    ),
                  )),

            const SizedBox(height: 24),
            const Text(
              'Team members can view and add to this horse\'s '
              'feed plan, wellness logs, training sessions, '
              'and reminders.',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}