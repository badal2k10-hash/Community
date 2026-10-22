import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../ui/common.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Icon(
              Icons.chair_alt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Baithak', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Small, in-person gatherings where strangers talk openly about life.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const NotTherapyNote(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Get started'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _send() {
    final err = ref.read(appProvider.notifier).sendOtp(_phone.text.trim());
    setState(() {
      _error = err;
      _sent = err == null;
    });
  }

  void _verify() {
    final err = ref
        .read(appProvider.notifier)
        .verifyOtp(_phone.text.trim(), _code.text.trim());
    if (err != null) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify your number')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _phone,
            enabled: !_sent,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixText: '+91 ',
              border: OutlineInputBorder(),
            ),
          ),
          if (_sent)
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sent ? _verify : _send,
              child: Text(_sent ? 'Verify' : 'Send OTP'),
            ),
          ),
          const Spacer(),
          const Text(
            'Demo mode: OTP is $demoOtp.\n'
            'Host: $demoHostPhone. Seeded attendee: $demoAttendeePhone.',
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends ConsumerStatefulWidget {
  final bool editing;
  const ProfileScreen({super.key, this.editing = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _interests;
  String? _age;
  bool _adult = false;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final me = ref.read(appProvider).me!;
    _name = TextEditingController(text: me.firstName);
    _bio = TextEditingController(text: me.bio);
    _interests = TextEditingController(text: me.interests.join(', '));
    _age = me.ageRange.isEmpty ? null : me.ageRange;
    _adult = widget.editing;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _interests.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(appProvider.notifier)
        .saveProfile(
          firstName: _name.text.trim(),
          ageRange: _age!,
          bio: _bio.text.trim(),
          interests: _interests.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        );
    if (widget.editing) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.editing ? 'Edit profile' : 'Set up your profile'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'First name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _age,
            decoration: const InputDecoration(
              labelText: 'Age range',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in ageRanges)
                DropdownMenuItem(value: a, child: Text(a)),
            ],
            onChanged: (v) => _age = v,
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bio,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Short bio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _interests,
            decoration: const InputDecoration(
              labelText: 'Interests (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
          if (!widget.editing)
            FormField<bool>(
              initialValue: _adult,
              validator: (_) => _adult ? null : 'You must be 18 or older.',
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _adult,
                    title: const Text('I confirm I am 18 or older'),
                    onChanged: (v) {
                      setState(() => _adult = v ?? false);
                      field.didChange(_adult);
                    },
                  ),
                  if (field.hasError)
                    Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const NotTherapyNote(),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    ),
  );
}
