import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../ui/common.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  // Verify these numbers with a local advisor before launch.
  static const _items = [
    (
      'Emergency services',
      '112',
      'If you or someone else is in immediate danger.',
    ),
    (
      'Tele-MANAS (India, 24x7)',
      '14416',
      'Free national mental health helpline.',
    ),
    ('iCall', '9152987821', 'Counselling by trained professionals.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support resources')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'A group can listen, but it cannot replace professional care. '
          'If you need more than a group can give, please reach out.',
        ),
        const SizedBox(height: 16),
        for (final (name, number, about) in _items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(name),
              subtitle: Text(about),
              trailing: SelectableText(number),
            ),
          ),
        const SizedBox(height: 8),
        const NotTherapyNote(),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminders = true;

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your profile, requests and feedback are permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(appProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(appProvider).me!;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(me.firstName),
            subtitle: Text('+91 ${me.phone} · ${me.ageRange}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => context.push('/profile-edit'),
          ),
          SwitchListTile(
            title: const Text('Reminders'),
            subtitle: const Text('24 hours and 2 hours before a gathering'),
            value: _reminders,
            onChanged: (v) => setState(() => _reminders = v),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Privacy'),
            subtitle: Text(
              'We store only your first name and a typed area. No contacts, '
              'no location tracking, no session photos.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: ref.read(appProvider.notifier).signOut,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Delete account and data'),
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}
