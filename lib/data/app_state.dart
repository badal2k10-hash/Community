import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

const demoOtp = '123456';
const demoHostPhone = '9999999999';
const demoAttendeePhone = '9000000000';

class AppState {
  final Map<String, AppUser> users;
  final List<Gathering> gatherings;
  final List<SeatRequest> requests;
  final List<Attendance> attendance;
  final List<SessionFeedback> feedback;
  final List<Report> reports;
  final Set<String> blocks;
  final Set<String> broadcasts;
  final List<Notice> notices;
  final String? currentUserId;

  const AppState({
    required this.users,
    required this.gatherings,
    required this.requests,
    required this.attendance,
    required this.feedback,
    required this.reports,
    required this.blocks,
    required this.broadcasts,
    required this.notices,
    this.currentUserId,
  });

  AppUser? get me => users[currentUserId];

  Gathering? gathering(String id) {
    for (final g in gatherings) {
      if (g.id == id) return g;
    }
    return null;
  }

  int held(String gatheringId) =>
      requests.where((r) => r.gatheringId == gatheringId && r.holdsSeat).length;

  int seatsLeft(Gathering g) => (g.seatCap - held(g.id)).clamp(0, maxSeats);

  SeatRequest? myRequest(String gatheringId) {
    for (final r in requests) {
      if (r.gatheringId == gatheringId &&
          r.userId == currentUserId &&
          r.status != SeatStatus.cancelled &&
          r.status != SeatStatus.declined) {
        return r;
      }
    }
    return null;
  }

  List<SeatRequest> requestsFor(String gatheringId) =>
      requests.where((r) => r.gatheringId == gatheringId).toList();

  AppState copyWith({
    Map<String, AppUser>? users,
    List<Gathering>? gatherings,
    List<SeatRequest>? requests,
    List<Attendance>? attendance,
    List<SessionFeedback>? feedback,
    List<Report>? reports,
    Set<String>? blocks,
    Set<String>? broadcasts,
    List<Notice>? notices,
    String? currentUserId,
    bool clearUser = false,
  }) => AppState(
    users: users ?? this.users,
    gatherings: gatherings ?? this.gatherings,
    requests: requests ?? this.requests,
    attendance: attendance ?? this.attendance,
    feedback: feedback ?? this.feedback,
    reports: reports ?? this.reports,
    blocks: blocks ?? this.blocks,
    broadcasts: broadcasts ?? this.broadcasts,
    notices: notices ?? this.notices,
    currentUserId: clearUser ? null : (currentUserId ?? this.currentUserId),
  );
}

/// In-memory backend. Replace with Firestore + Cloud Functions; the server
/// must enforce the seat cap, address unlock and role checks.
class AppController extends Notifier<AppState> {
  final List<DateTime> _otpRequests = [];
  int _seq = 100;

  String _id(String p) => '$p${_seq++}';

  @override
  AppState build() => _seed();

  AppState _seed() {
    final now = DateTime.now();
    const host = AppUser(
      id: 'host',
      phone: demoHostPhone,
      firstName: 'Aarav',
      ageRange: '25-34',
      bio: 'Host of the weekly baithak.',
      role: Role.host,
      profileComplete: true,
      hostReviewed: true,
    );
    const demo = AppUser(
      id: 'demo',
      phone: demoAttendeePhone,
      firstName: 'Meera',
      ageRange: '25-34',
      bio: 'Moved cities last year, still finding my people.',
      interests: ['Books', 'Walking'],
      profileComplete: true,
      hostReviewed: true,
    );
    final others = [
      for (final (i, n) in ['Riya', 'Kabir', 'Sana', 'Dev'].indexed)
        AppUser(
          id: 'u$i',
          phone: '80000000$i$i',
          firstName: n,
          ageRange: ageRanges[i % ageRanges.length],
          bio: 'Here to listen and share.',
          interests: const ['Music', 'Cooking'],
          profileComplete: true,
          hostReviewed: i < 2,
        ),
    ];
    final gatherings = [
      Gathering(
        id: 'gpast',
        hostId: 'host',
        theme: 'Things we never say at home',
        activity: 'Pass-the-cup talking circle',
        description: 'A gentle circle about family expectations.',
        area: 'Indiranagar',
        address: '14, 2nd Cross, Indiranagar',
        start: now.subtract(const Duration(days: 6)),
        seatCap: 18,
        rules: defaultRules,
      ),
      Gathering(
        id: 'g1',
        hostId: 'host',
        theme: 'The week that wore us down',
        activity: 'Chai and one-word check-in',
        description: 'Share the one thing that weighed on you this week. No fixing, only listening.',
        area: 'Indiranagar',
        address: '14, 2nd Cross, Indiranagar',
        start: now.add(const Duration(days: 2, hours: 3)),
        seatCap: 18,
        rules: defaultRules,
      ),
      Gathering(
        id: 'g2',
        hostId: 'host',
        theme: 'Friendship after 30',
        activity: 'Story swap in small groups',
        description: 'How do friendships change as life gets busy?',
        area: 'Indiranagar',
        address: '14, 2nd Cross, Indiranagar',
        start: now.add(const Duration(days: 9, hours: 2)),
        seatCap: 20,
        rules: defaultRules,
      ),
    ];
    SeatRequest req(
      String id,
      String g,
      String u,
      SeatStatus s, {
      bool accepted = false,
      String note = 'I want to meet new people.',
    }) => SeatRequest(
      id: id,
      gatheringId: g,
      userId: u,
      note: note,
      status: s,
      createdAt: now.subtract(const Duration(days: 1)),
      rulesAcceptedAt: accepted ? now : null,
    );
    return AppState(
      users: {
        for (final u in [host, demo, ...others]) u.id: u,
      },
      gatherings: gatherings,
      requests: [
        req('r0', 'gpast', 'demo', SeatStatus.approved, accepted: true),
        req(
          'r1',
          'g1',
          'u0',
          SeatStatus.pending,
          note: 'Feeling isolated lately and want to talk.',
        ),
        req('r2', 'g1', 'u1', SeatStatus.pending),
        req('r3', 'g1', 'u2', SeatStatus.approved, accepted: true),
      ],
      attendance: const [Attendance('gpast', 'demo', true)],
      feedback: const [],
      reports: const [],
      blocks: const {},
      broadcasts: const {},
      notices: const [],
    );
  }

  // Auth

  String? sendOtp(String phone) {
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit phone number.';
    }
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    _otpRequests.removeWhere((t) => t.isBefore(cutoff));
    if (_otpRequests.length >= 5) {
      return 'Too many OTP requests. Try again in a few minutes.';
    }
    _otpRequests.add(DateTime.now());
    return null;
  }

  String? verifyOtp(String phone, String code) {
    if (code != demoOtp) return 'Incorrect code. Demo code is $demoOtp.';
    final existing = state.users.values.where((u) => u.phone == phone);
    if (existing.isNotEmpty) {
      if (existing.first.status == UserStatus.suspended) {
        return 'This account has been suspended.';
      }
      state = state.copyWith(currentUserId: existing.first.id);
      return null;
    }
    final user = AppUser(id: _id('u'), phone: phone);
    state = state.copyWith(
      users: {...state.users, user.id: user},
      currentUserId: user.id,
    );
    return null;
  }

  void signOut() => state = state.copyWith(clearUser: true);

  void deleteAccount() {
    final id = state.currentUserId;
    if (id == null) return;
    for (final r in state.requests.where(
      (r) => r.userId == id && r.holdsSeat,
    )) {
      _promoteWaitlist(r.gatheringId, excludingUser: id);
    }
    state = state.copyWith(
      users: {...state.users}..remove(id),
      requests: state.requests.where((r) => r.userId != id).toList(),
      attendance: state.attendance.where((a) => a.userId != id).toList(),
      feedback: state.feedback.where((f) => f.userId != id).toList(),
      notices: state.notices.where((n) => n.userId != id).toList(),
      clearUser: true,
    );
  }

  void saveProfile({
    required String firstName,
    required String ageRange,
    required String bio,
    required List<String> interests,
  }) {
    final me = state.me!;
    _putUser(
      me.copyWith(
        firstName: firstName,
        ageRange: ageRange,
        bio: bio,
        interests: interests,
        profileComplete: true,
      ),
    );
  }

  // Attendee

  String? requestSeat(String gatheringId, String note) {
    final me = state.me!;
    final g = state.gathering(gatheringId);
    if (g == null || g.cancelled || g.isPast) {
      return 'This gathering is closed.';
    }
    if (me.isPaused) {
      return 'Your account is paused. Requests are unavailable for now.';
    }
    if (state.myRequest(gatheringId) != null) return 'You already requested.';
    _putRequest(
      SeatRequest(
        id: _id('r'),
        gatheringId: gatheringId,
        userId: me.id,
        note: note.trim(),
        status: SeatStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    return null;
  }

  void acceptRules(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    _putRequest(r.copyWith(rulesAcceptedAt: DateTime.now()));
  }

  void cancelRequest(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    final g = state.gathering(r.gatheringId)!;
    _putRequest(r.copyWith(status: SeatStatus.cancelled));
    if (r.holdsSeat) {
      if (g.start.difference(DateTime.now()) < const Duration(hours: 24)) {
        final u = state.users[r.userId]!;
        _putUser(u.copyWith(lateCancels: u.lateCancels + 1));
      }
      _promoteWaitlist(g.id);
    }
  }

  void submitFeedback(String gatheringId, int safety, int welcome, String c) {
    state = state.copyWith(
      feedback: [
        ...state.feedback,
        SessionFeedback(gatheringId, state.currentUserId!, safety, welcome, c),
      ],
    );
  }

  bool hasFeedback(String gatheringId) => state.feedback.any(
    (f) => f.gatheringId == gatheringId && f.userId == state.currentUserId,
  );

  // Safety

  void reportUser(String reportedId, String? gatheringId, String reason) {
    final reports = [
      ...state.reports,
      Report(_id('rep'), state.currentUserId!, reportedId, gatheringId, reason),
    ];
    final reporters = reports
        .where((r) => r.reportedUserId == reportedId)
        .map((r) => r.reporterId)
        .toSet();
    state = state.copyWith(reports: reports);
    if (reporters.length >= 2) {
      final u = state.users[reportedId];
      if (u != null && u.status == UserStatus.active) {
        _putUser(u.copyWith(status: UserStatus.paused));
      }
    }
  }

  void blockUser(String userId) => state = state.copyWith(
    blocks: {...state.blocks, '${state.currentUserId}>$userId'},
  );

  bool isBlocked(String userId) =>
      state.blocks.contains('${state.currentUserId}>$userId');

  // Host

  void createGathering({
    required String theme,
    required String activity,
    required String description,
    required String area,
    required String address,
    required DateTime start,
    required int seats,
    required List<String> rules,
  }) {
    final g = Gathering(
      id: _id('g'),
      hostId: state.currentUserId!,
      theme: theme,
      activity: activity,
      description: description,
      area: area,
      address: address,
      start: start,
      seatCap: seats.clamp(1, maxSeats),
      rules: rules,
    );
    state = state.copyWith(gatherings: [...state.gatherings, g]);
  }

  String? approve(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    final g = state.gathering(r.gatheringId)!;
    final user = state.users[r.userId]!;
    _putUser(user.copyWith(hostReviewed: true));
    if (state.held(g.id) >= g.seatCap) {
      _putRequest(r.copyWith(status: SeatStatus.waitlisted));
      _notify(r.userId, 'You are on the waitlist', g.theme);
      return 'Seats are full. Added to the waitlist.';
    }
    _putRequest(r.copyWith(status: SeatStatus.approved));
    _notify(r.userId, 'Seat approved', 'Accept the ground rules to confirm.');
    return null;
  }

  void decline(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    _putRequest(r.copyWith(status: SeatStatus.declined));
    _notify(
      r.userId,
      'Not this time',
      'Thanks for asking. Please try another date.',
    );
  }

  void waitlist(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    _putRequest(r.copyWith(status: SeatStatus.waitlisted));
  }

  void removeAttendee(String requestId) {
    final r = state.requests.firstWhere((r) => r.id == requestId);
    _putRequest(r.copyWith(status: SeatStatus.cancelled));
    _promoteWaitlist(r.gatheringId);
  }

  void removeFromCommunity(String userId) {
    final u = state.users[userId];
    if (u == null) return;
    _putUser(u.copyWith(status: UserStatus.suspended));
    for (final r in state.requests.where(
      (r) => r.userId == userId && r.status != SeatStatus.cancelled,
    )) {
      _putRequest(r.copyWith(status: SeatStatus.cancelled));
    }
  }

  void cancelGathering(String gatheringId) {
    final g = state.gathering(gatheringId)!;
    for (final r in state.requests.where(
      (r) => r.gatheringId == gatheringId && r.holdsSeat,
    )) {
      _notify(
        r.userId,
        'Gathering cancelled',
        '${g.theme} has been cancelled.',
      );
    }
    state = state.copyWith(
      gatherings: [
        for (final x in state.gatherings)
          x.id == gatheringId ? x.copyWith(cancelled: true) : x,
      ],
    );
  }

  String? broadcast(String gatheringId, String message) {
    if (state.broadcasts.contains(gatheringId)) {
      return 'You already sent the one allowed message.';
    }
    for (final r in state.requests.where(
      (r) => r.gatheringId == gatheringId && r.confirmed,
    )) {
      _notify(r.userId, 'From your host', message);
    }
    state = state.copyWith(broadcasts: {...state.broadcasts, gatheringId});
    return null;
  }

  void markAttendance(String gatheringId, String userId, bool attended) {
    final list = [
      ...state.attendance.where(
        (a) => !(a.gatheringId == gatheringId && a.userId == userId),
      ),
      Attendance(gatheringId, userId, attended),
    ];
    state = state.copyWith(attendance: list);
    final noShows = list.where((a) => a.userId == userId && !a.attended).length;
    final u = state.users[userId];
    if (u != null && noShows >= 3) {
      _putUser(
        u.copyWith(pausedUntil: DateTime.now().add(const Duration(days: 30))),
      );
    }
  }

  // Helpers

  void _promoteWaitlist(String gatheringId, {String? excludingUser}) {
    final g = state.gathering(gatheringId)!;
    if (state.held(gatheringId) >= g.seatCap) return;
    final queue =
        state.requests
            .where(
              (r) =>
                  r.gatheringId == gatheringId &&
                  r.status == SeatStatus.waitlisted &&
                  r.userId != excludingUser,
            )
            .toList()
          ..sort((a, b) {
            final late = state.users[a.userId]!.lateCancels.compareTo(
              state.users[b.userId]!.lateCancels,
            );
            return late != 0 ? late : a.createdAt.compareTo(b.createdAt);
          });
    if (queue.isEmpty) return;
    _putRequest(queue.first.copyWith(status: SeatStatus.approved));
    _notify(queue.first.userId, 'A seat opened up', g.theme);
  }

  void _notify(String userId, String title, String body) {
    state = state.copyWith(
      notices: [...state.notices, Notice(userId, title, body, DateTime.now())],
    );
  }

  void _putUser(AppUser u) =>
      state = state.copyWith(users: {...state.users, u.id: u});

  void _putRequest(SeatRequest r) {
    final exists = state.requests.any((x) => x.id == r.id);
    state = state.copyWith(
      requests: exists
          ? [for (final x in state.requests) x.id == r.id ? r : x]
          : [...state.requests, r],
    );
  }
}

final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
