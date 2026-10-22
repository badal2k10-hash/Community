import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../ui/common.dart';

class HostHomeScreen extends ConsumerWidget {
  const HostHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final mine = s.gatherings.where((g) => g.hostId == s.currentUserId).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return Scaffold(
      appBar: AppBar(title: const Text('Host')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/host/create'),
        icon: const Icon(Icons.add),
        label: const Text('New gathering'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mine.isEmpty) const Text('Create your first gathering.'),
          for (final g in mine)
            GatheringCard(
              gathering: g,
              onTap: () => context.push('/host/g/${g.id}'),
            ),
        ],
      ),
    );
  }
}

class CreateGatheringScreen extends ConsumerStatefulWidget {
  const CreateGatheringScreen({super.key});

  @override
  ConsumerState<CreateGatheringScreen> createState() => _CreateGatheringState();
}

class _CreateGatheringState extends ConsumerState<CreateGatheringScreen> {
  final _form = GlobalKey<FormState>();
  final _theme = TextEditingController();
  final _activity = TextEditingController();
  final _desc = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _seats = TextEditingController(text: '15');
  final _rules = TextEditingController(text: defaultRules.join('\n'));
  DateTime? _start;

  @override
  void dispose() {
    for (final c in [
      _theme,
      _activity,
      _desc,
      _area,
      _address,
      _seats,
      _rules,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 30),
    );
    if (time == null) return;
    setState(
      () => _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_start == null || _start!.isBefore(DateTime.now())) {
      snack(context, 'Pick a future date and time.');
      return;
    }
    ref
        .read(appProvider.notifier)
        .createGathering(
          theme: _theme.text.trim(),
          activity: _activity.text.trim(),
          description: _desc.text.trim(),
          area: _area.text.trim(),
          address: _address.text.trim(),
          start: _start!,
          seats: int.parse(_seats.text),
          rules: _rules.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        );
    context.pop();
  }

  Widget _field(
    String label,
    TextEditingController c, {
    int lines = 1,
    String? Function(String?)? validator,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      keyboardType: type,
      validator: validator ?? _required,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create gathering')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('Theme', _theme),
          _field('Activity', _activity),
          _field('Description', _desc, lines: 3),
          _field('Area (public)', _area),
          _field('Full address (shown only to approved attendees)', _address),
          _field(
            'Seats (max $maxSeats)',
            _seats,
            type: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 1 || n > maxSeats)
                  ? 'Enter 1 to $maxSeats'
                  : null;
            },
          ),
          OutlinedButton.icon(
            onPressed: _pickStart,
            icon: const Icon(Icons.event),
            label: Text(
              _start == null ? 'Pick date and time' : fmtDateTime(_start!),
            ),
          ),
          const SizedBox(height: 12),
          _field('Ground rules (one per line)', _rules, lines: 5),
          FilledButton(onPressed: _save, child: const Text('Publish')),
        ],
      ),
    ),
  );
}

class RequestsScreen extends ConsumerWidget {
  final String gatheringId;
  const RequestsScreen({super.key, required this.gatheringId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = s.gathering(gatheringId)!;
    final ctrl = ref.read(appProvider.notifier);
    final items =
        s
            .requestsFor(gatheringId)
            .where(
              (r) =>
                  r.status == SeatStatus.pending ||
                  r.status == SeatStatus.waitlisted,
            )
            .toList()
          ..sort((a, b) {
            final late = s.users[a.userId]!.lateCancels.compareTo(
              s.users[b.userId]!.lateCancels,
            );
            return late != 0 ? late : a.createdAt.compareTo(b.createdAt);
          });
    return Scaffold(
      appBar: AppBar(
        title: Text('Requests · ${s.held(g.id)}/${g.seatCap} seats'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No pending requests.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in items)
                  _RequestCard(
                    request: r,
                    user: s.users[r.userId]!,
                    attended: s.attendance
                        .where((a) => a.userId == r.userId && a.attended)
                        .length,
                    noShows: s.attendance
                        .where((a) => a.userId == r.userId && !a.attended)
                        .length,
                    blocked: ctrl.isBlocked(r.userId),
                    gatheringId: g.id,
                    onApprove: () {
                      final msg = ctrl.approve(r.id);
                      if (msg != null) snack(context, msg);
                    },
                    onDecline: () => ctrl.decline(r.id),
                    onWaitlist: () => ctrl.waitlist(r.id),
                  ),
              ],
            ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final SeatRequest request;
  final AppUser user;
  final int attended;
  final int noShows;
  final bool blocked;
  final String gatheringId;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onWaitlist;

  const _RequestCard({
    required this.request,
    required this.user,
    required this.attended,
    required this.noShows,
    required this.blocked,
    required this.gatheringId,
    required this.onApprove,
    required this.onDecline,
    required this.onWaitlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${user.firstName} · ${user.ageRange}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusChip(request),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'report') {
                    showReportSheet(
                      context,
                      ref,
                      userId: user.id,
                      gatheringId: gatheringId,
                    );
                  } else {
                    ref.read(appProvider.notifier).removeFromCommunity(user.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Report or block'),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from community'),
                  ),
                ],
              ),
            ],
          ),
          if (user.bio.isNotEmpty) Text(user.bio),
          if (user.interests.isNotEmpty)
            Text('Interests: ${user.interests.join(', ')}'),
          const SizedBox(height: 4),
          Text(
            'Attended $attended · No-shows $noShows · Late cancels ${user.lateCancels}',
          ),
          if (user.isPaused) const Text('Account paused pending review'),
          if (blocked) const Text('You blocked this person'),
          const SizedBox(height: 8),
          Text('"${request.note}"'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: user.isPaused ? null : onApprove,
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: onDecline,
                child: const Text('Decline'),
              ),
              if (request.status == SeatStatus.pending)
                TextButton(
                  onPressed: onWaitlist,
                  child: const Text('Waitlist'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class DashboardScreen extends ConsumerWidget {
  final String gatheringId;
  const DashboardScreen({super.key, required this.gatheringId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = s.gathering(gatheringId)!;
    final ctrl = ref.read(appProvider.notifier);
    final all = s.requestsFor(gatheringId);
    final pending = all.where((r) => r.status == SeatStatus.pending).length;
    final waitlisted = all
        .where((r) => r.status == SeatStatus.waitlisted)
        .length;
    final seated = all.where((r) => r.holdsSeat).toList();
    final fb = s.feedback.where((f) => f.gatheringId == gatheringId).toList();
    double avg(int Function(SessionFeedback) f) =>
        fb.isEmpty ? 0 : fb.map(f).reduce((a, b) => a + b) / fb.length;
    final reports = s.reports
        .where((r) => r.gatheringId == gatheringId)
        .toList();
    final started = g.start.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Gathering dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(g.theme, style: Theme.of(context).textTheme.headlineSmall),
          Text('${fmtDateTime(g.start)} · ${g.area}'),
          Text(
            '${s.held(g.id)}/${g.seatCap} seats held'
            '${g.cancelled ? ' · CANCELLED' : ''}',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/host/g/${g.id}/requests'),
            icon: const Icon(Icons.inbox_outlined),
            label: Text('Requests ($pending pending, $waitlisted waitlisted)'),
          ),
          const SectionTitle('Seated attendees'),
          if (seated.isEmpty) const Text('No one yet.'),
          for (final r in seated)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.users[r.userId]!.firstName),
              subtitle: Text(
                r.confirmed ? 'Confirmed' : 'Approved, awaiting rules',
              ),
              trailing: Wrap(
                children: [
                  if (started) ...[
                    IconButton(
                      tooltip: 'Attended',
                      icon: Icon(
                        Icons.check_circle,
                        color: _att(s, g.id, r.userId) == true
                            ? Colors.green
                            : null,
                      ),
                      onPressed: () =>
                          ctrl.markAttendance(g.id, r.userId, true),
                    ),
                    IconButton(
                      tooltip: 'No-show',
                      icon: Icon(
                        Icons.cancel,
                        color: _att(s, g.id, r.userId) == false
                            ? Colors.red
                            : null,
                      ),
                      onPressed: () =>
                          ctrl.markAttendance(g.id, r.userId, false),
                    ),
                  ] else
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => ctrl.removeAttendee(r.id),
                    ),
                ],
              ),
            ),
          if (!g.cancelled && !started) ...[
            const SectionTitle('Message everyone (once)'),
            OutlinedButton.icon(
              onPressed: s.broadcasts.contains(g.id)
                  ? null
                  : () => _broadcast(context, ctrl, g.id),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Send arrival details'),
            ),
          ],
          const SectionTitle('Feedback (anonymous)'),
          if (fb.isEmpty)
            const Text('No feedback yet.')
          else ...[
            Text(
              'Safe: ${avg((f) => f.safety).toStringAsFixed(1)} / 5 · '
              'Welcome: ${avg((f) => f.welcome).toStringAsFixed(1)} / 5 · ${fb.length} responses',
            ),
            for (final f in fb.where((f) => f.comment.isNotEmpty))
              ListTile(contentPadding: EdgeInsets.zero, title: Text(f.comment)),
          ],
          const SectionTitle('Reports'),
          if (reports.isEmpty) const Text('No reports.'),
          for (final r in reports)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'About ${s.users[r.reportedUserId]?.firstName ?? 'removed user'}',
              ),
              subtitle: Text(r.reason),
            ),
          if (!g.cancelled && !started) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ctrl.cancelGathering(g.id),
              child: Text(
                'Cancel gathering',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool? _att(AppState s, String gid, String uid) {
    for (final a in s.attendance) {
      if (a.gatheringId == gid && a.userId == uid) return a.attended;
    }
    return null;
  }

  Future<void> _broadcast(
    BuildContext context,
    AppController ctrl,
    String gid,
  ) async {
    final c = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arrival details'),
        content: TextField(controller: c, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (send == true && c.text.trim().isNotEmpty) {
      ctrl.broadcast(gid, c.text.trim());
    }
    c.dispose();
  }
}
