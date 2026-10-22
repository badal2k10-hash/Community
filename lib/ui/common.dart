import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../data/models.dart';

String fmtDateTime(DateTime d) => DateFormat('EEE, d MMM · h:mm a').format(d);

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class NotTherapyNote extends StatelessWidget {
  const NotTherapyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a peer community, not therapy or clinical support. '
              'If you need professional help, open Resources.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class RulesList extends StatelessWidget {
  final List<String> rules;
  const RulesList(this.rules, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final r in rules)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(r)),
            ],
          ),
        ),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class StatusChip extends StatelessWidget {
  final SeatRequest request;
  const StatusChip(this.request, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (request.status) {
      SeatStatus.pending => ('Requested', Colors.orange),
      SeatStatus.approved =>
        request.confirmed
            ? ('Confirmed', Colors.green)
            : ('Approved - accept rules', Colors.blue),
      SeatStatus.waitlisted => ('Waitlisted', Colors.amber.shade800),
      SeatStatus.declined => ('Declined', Colors.red),
      SeatStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color)),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class GatheringCard extends ConsumerWidget {
  final Gathering gathering;
  final VoidCallback onTap;
  const GatheringCard({
    super.key,
    required this.gathering,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final left = s.seatsLeft(gathering);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gathering.theme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(fmtDateTime(gathering.start)),
              Text(gathering.area),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_seat_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    gathering.cancelled
                        ? 'Cancelled'
                        : left == 0
                        ? 'Full - waitlist open'
                        : '$left seats left',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String? gatheringId,
}) {
  const reasons = [
    'Made me feel unsafe',
    'Disrespectful or judgmental',
    'Broke confidentiality',
    'Inappropriate behaviour',
    'Other',
  ];
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Report this person'),
            subtitle: Text('The admin is alerted. Your identity stays hidden.'),
          ),
          for (final r in reasons)
            ListTile(
              title: Text(r),
              onTap: () {
                ref
                    .read(appProvider.notifier)
                    .reportUser(userId, gatheringId, r);
                Navigator.pop(ctx);
                snack(context, 'Report sent to the admin.');
              },
            ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block instead'),
            onTap: () {
              ref.read(appProvider.notifier).blockUser(userId);
              Navigator.pop(ctx);
              snack(context, 'Blocked.');
            },
          ),
        ],
      ),
    ),
  );
}

class ResourcesButton extends StatelessWidget {
  const ResourcesButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Support resources',
    icon: const Icon(Icons.favorite_border),
    onPressed: () => context.go('/resources'),
  );
}
