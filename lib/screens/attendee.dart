import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../ui/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final mine = s.requests.where((r) {
      final g = s.gathering(r.gatheringId);
      return r.userId == s.currentUserId &&
          r.confirmed &&
          g != null &&
          !g.isPast &&
          !g.cancelled;
    }).toList();
    final upcoming =
        s.gatherings.where((g) => !g.isPast && !g.cancelled).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final unread = s.notices.where((n) => n.userId == s.currentUserId).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi ${s.me!.firstName}'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notices'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mine.isNotEmpty) ...[
            const SectionTitle('My confirmed seats'),
            for (final r in mine)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  title: Text(s.gathering(r.gatheringId)!.theme),
                  subtitle: Text(
                    fmtDateTime(s.gathering(r.gatheringId)!.start),
                  ),
                  trailing: const Icon(Icons.confirmation_number_outlined),
                  onTap: () => context.push('/ticket/${r.id}'),
                ),
              ),
          ],
          const SectionTitle('Upcoming gatherings'),
          if (upcoming.isEmpty)
            const Text('Nothing scheduled yet. Check back soon.'),
          for (final g in upcoming)
            GatheringCard(
              gathering: g,
              onTap: () => context.push('/g/${g.id}'),
            ),
        ],
      ),
    );
  }
}

class GatheringDetailScreen extends ConsumerWidget {
  final String id;
  const GatheringDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = s.gathering(id);
    if (g == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Gathering not found.')),
      );
    }
    final mine = s.myRequest(id);
    final full = s.seatsLeft(g) == 0;
    final open = !g.isPast && !g.cancelled;
    return Scaffold(
      appBar: AppBar(title: const Text('Gathering')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(g.theme, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${fmtDateTime(g.start)} · ${g.area}'),
          Text(
            g.cancelled
                ? 'Cancelled'
                : '${s.seatsLeft(g)} of ${g.seatCap} seats left',
          ),
          const SectionTitle('Activity'),
          Text(g.activity),
          const SectionTitle('What to expect'),
          Text(g.description),
          const SectionTitle('Ground rules'),
          RulesList(g.rules),
          const SectionTitle('Address'),
          const Text(
            'The exact address is shared after approval, 2 hours before the start.',
          ),
          const SizedBox(height: 16),
          const NotTherapyNote(),
          const SizedBox(height: 24),
          if (open)
            if (mine == null)
              FilledButton(
                onPressed: () => context.push('/g/$id/request'),
                child: Text(
                  full ? 'Request a waitlist spot' : 'Request a seat',
                ),
              )
            else ...[
              Align(alignment: Alignment.centerLeft, child: StatusChip(mine)),
              if (mine.holdsSeat)
                FilledButton(
                  onPressed: () => context.push('/ticket/${mine.id}'),
                  child: Text(
                    mine.confirmed ? 'View ticket' : 'Accept rules to confirm',
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class RequestSeatScreen extends ConsumerStatefulWidget {
  final String id;
  const RequestSeatScreen({super.key, required this.id});

  @override
  ConsumerState<RequestSeatScreen> createState() => _RequestSeatScreenState();
}

class _RequestSeatScreenState extends ConsumerState<RequestSeatScreen> {
  final _note = TextEditingController();
  bool _read = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final err = ref
        .read(appProvider.notifier)
        .requestSeat(widget.id, _note.text);
    if (err != null) {
      snack(context, err);
      return;
    }
    snack(context, 'Request sent. We will notify you when the host responds.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(appProvider).gathering(widget.id)!;
    final valid = _note.text.trim().length >= 10 && _read;
    return Scaffold(
      appBar: AppBar(title: const Text('Request a seat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(g.theme, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 4,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Why do you want to come?',
              helperText: 'At least 10 characters',
              border: OutlineInputBorder(),
            ),
          ),
          const SectionTitle('Ground rules'),
          RulesList(g.rules),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _read,
            title: const Text('I have read the ground rules'),
            onChanged: (v) => setState(() => _read = v ?? false),
          ),
          const NotTherapyNote(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: valid ? _submit : null,
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

class MyGatheringsScreen extends ConsumerWidget {
  const MyGatheringsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final mine = s.requests.where((r) => r.userId == s.currentUserId).toList()
      ..sort(
        (a, b) => s
            .gathering(a.gatheringId)!
            .start
            .compareTo(s.gathering(b.gatheringId)!.start),
      );
    bool isPast(SeatRequest r) {
      final g = s.gathering(r.gatheringId)!;
      return g.isPast ||
          g.cancelled ||
          r.status == SeatStatus.declined ||
          r.status == SeatStatus.cancelled;
    }

    Widget list(List<SeatRequest> items, {required bool past}) {
      if (items.isEmpty) return const Center(child: Text('Nothing here yet.'));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final r in items) _RequestTile(r, past: past)],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My gatherings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            list(mine.where((r) => !isPast(r)).toList(), past: false),
            list(mine.where(isPast).toList().reversed.toList(), past: true),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final SeatRequest request;
  final bool past;
  const _RequestTile(this.request, {required this.past});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = s.gathering(request.gatheringId)!;
    final attended = s.attendance.any(
      (a) => a.gatheringId == g.id && a.userId == request.userId && a.attended,
    );
    final canFeedback =
        past &&
        attended &&
        !s.feedback.any(
          (f) => f.gatheringId == g.id && f.userId == request.userId,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.theme, style: Theme.of(context).textTheme.titleMedium),
            Text(fmtDateTime(g.start)),
            Row(
              children: [
                StatusChip(request),
                const Spacer(),
                if (!past && request.holdsSeat)
                  TextButton(
                    onPressed: () => context.push('/ticket/${request.id}'),
                    child: Text(request.confirmed ? 'Ticket' : 'Confirm'),
                  ),
                if (!past)
                  TextButton(
                    onPressed: () => _confirmCancel(context, ref),
                    child: const Text('Cancel'),
                  ),
                if (canFeedback)
                  FilledButton(
                    onPressed: () => context.push('/feedback/${g.id}'),
                    child: const Text('Give feedback'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this seat?'),
        content: const Text(
          'Your seat goes to the next person on the waitlist. '
          'Repeated late cancellations lower your request priority.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel seat'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(appProvider.notifier).cancelRequest(request.id);
  }
}

class TicketScreen extends ConsumerWidget {
  final String requestId;
  const TicketScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final r = s.requests.where((r) => r.id == requestId).firstOrNull;
    final g = r == null ? null : s.gathering(r.gatheringId);
    if (r == null || g == null || !r.holdsSeat) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No active seat for this gathering.')),
      );
    }
    final host = s.users[g.hostId]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Your ticket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(g.theme, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(fmtDateTime(g.start)),
          if (!r.confirmed) ...[
            const SectionTitle('Accept the ground rules to confirm your seat'),
            RulesList(g.rules),
            const SizedBox(height: 16),
            const NotTherapyNote(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(appProvider.notifier).acceptRules(r.id),
              child: const Text('I accept - confirm my seat'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _Countdown(g.start),
            const SectionTitle('Address'),
            if (DateTime.now().isBefore(g.addressUnlockAt)) ...[
              Text('Area: ${g.area}'),
              Text(
                'The full address unlocks at ${fmtDateTime(g.addressUnlockAt)}.',
              ),
            ] else ...[
              Text(g.address, style: Theme.of(context).textTheme.titleMedium),
              const SectionTitle('Host contact'),
              Text('${host.firstName} · +91 ${host.phone}'),
            ],
            const SizedBox(height: 24),
            const NotTherapyNote(),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final DateTime start;
  const _Countdown(this.start);

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
    builder: (context, _) {
      final d = start.difference(DateTime.now());
      final text = d.isNegative
          ? 'Started'
          : '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m to go';
      return Text(text, style: Theme.of(context).textTheme.titleLarge);
    },
  );
}

class FeedbackScreen extends ConsumerStatefulWidget {
  final String gatheringId;
  const FeedbackScreen({super.key, required this.gatheringId});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int _safety = 0;
  int _welcome = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Widget _stars(String label, int value, ValueChanged<int> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(label),
      Row(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i',
              icon: Icon(i <= value ? Icons.star : Icons.star_border),
              onPressed: () => onChanged(i),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final g = s.gathering(widget.gatheringId)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Private feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(g.theme, style: Theme.of(context).textTheme.titleLarge),
          const Text('Only the host and admin see this, never your name.'),
          _stars(
            'How safe did you feel?',
            _safety,
            (v) => setState(() => _safety = v),
          ),
          _stars(
            'How welcome did you feel?',
            _welcome,
            (v) => setState(() => _welcome = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _safety == 0 || _welcome == 0
                ? null
                : () {
                    ref
                        .read(appProvider.notifier)
                        .submitFeedback(
                          g.id,
                          _safety,
                          _welcome,
                          _comment.text.trim(),
                        );
                    context.pop();
                    snack(context, 'Thank you for your feedback.');
                  },
            child: const Text('Submit'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report someone from this gathering'),
            onPressed: () => _pickPerson(context, s, g),
          ),
        ],
      ),
    );
  }

  void _pickPerson(BuildContext context, AppState s, Gathering g) {
    final others = s.requests
        .where(
          (r) =>
              r.gatheringId == g.id &&
              r.confirmed &&
              r.userId != s.currentUserId,
        )
        .map((r) => s.users[r.userId])
        .whereType<AppUser>()
        .toList();
    final host = s.users[g.hostId];
    if (host != null && host.id != s.currentUserId) others.add(host);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Who are you reporting?')),
            for (final u in others)
              ListTile(
                title: Text(u.firstName),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportSheet(
                    context,
                    ref,
                    userId: u.id,
                    gatheringId: g.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final mine = s.notices
        .where((n) => n.userId == s.currentUserId)
        .toList()
        .reversed
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: mine.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView(
              children: [
                for (final n in mine)
                  ListTile(
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: Text(fmtDateTime(n.at)),
                  ),
              ],
            ),
    );
  }
}
