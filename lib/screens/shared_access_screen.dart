import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() { _loading = true; _error = null; _success = null; });
    final fs = context.read<FirestoreService>();

    try {
      final uid = await fs.findUidByEmail(email);
      if (uid == null) {
        setState(() {
          _error =
              'No NutriEquine account found for $email. Ask them to sign up first.';
        });
        return;
      }
      if (uid == fs.uid) {
        setState(() => _error = 'You cannot share with yourself.');
        return;
      }
      if (widget.horse.sharedWith.contains(uid)) {
        setState(() => _error = '$email already has access.');
        return;
      }
      await fs.shareHorseWithUser(widget.horse.id, uid);
      setState(() {
        _success = '$email now has access to ${widget.horse.name}.';
        _emailCtrl.clear();
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Team Access — ${widget.horse.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share this horse\'s profile with your vet, trainer, or barn staff. They\'ll be able to view and add to the feed plan, wellness log, and reminders.',
              style: TextStyle(color: Colors.grey),
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
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _invite,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Invite'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_success != null) ...[
              const SizedBox(height: 8),
              Text(_success!, style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 24),
            Text('Current team (${widget.horse.sharedWith.length} members)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (widget.horse.sharedWith.isEmpty)
              const Text('No one else has access yet.',
                  style: TextStyle(color: Colors.grey))
            else
              ...widget.horse.sharedWith.map((uid) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(uid),
                      subtitle: const Text('Team member'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        tooltip: 'Remove access',
                        onPressed: () async {
                          await context
                              .read<FirestoreService>()
                              .removeSharedAccess(widget.horse.id, uid);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Access removed.')),
                            );
                          }
                        },
                      ),
                    ),
                  )),
            const SizedBox(height: 24),
            const Text(
              'Note: Team members must already have a NutriEquine account. They\'ll see this horse appear in their Horses tab automatically after being added.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
