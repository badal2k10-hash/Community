enum Role { attendee, host, admin }

enum UserStatus { active, paused, suspended }

enum SeatStatus { pending, approved, declined, waitlisted, cancelled }

const maxSeats = 20;
const ageRanges = ['18-24', '25-34', '35-44', '45+'];
const defaultRules = [
  'What is said in the room stays in the room.',
  'No judgment. Listen to understand.',
  'Offer advice only when someone asks for it.',
  'Equal speaking time for everyone.',
];

class AppUser {
  final String id;
  final String phone;
  final String firstName;
  final String ageRange;
  final String bio;
  final List<String> interests;
  final Role role;
  final UserStatus status;
  final bool profileComplete;
  final bool hostReviewed;
  final DateTime? pausedUntil;
  final int lateCancels;

  const AppUser({
    required this.id,
    required this.phone,
    this.firstName = '',
    this.ageRange = '',
    this.bio = '',
    this.interests = const [],
    this.role = Role.attendee,
    this.status = UserStatus.active,
    this.profileComplete = false,
    this.hostReviewed = false,
    this.pausedUntil,
    this.lateCancels = 0,
  });

  bool get isPaused =>
      status != UserStatus.active ||
      (pausedUntil != null && pausedUntil!.isAfter(DateTime.now()));

  AppUser copyWith({
    String? firstName,
    String? ageRange,
    String? bio,
    List<String>? interests,
    UserStatus? status,
    bool? profileComplete,
    bool? hostReviewed,
    DateTime? pausedUntil,
    int? lateCancels,
  }) => AppUser(
    id: id,
    phone: phone,
    firstName: firstName ?? this.firstName,
    ageRange: ageRange ?? this.ageRange,
    bio: bio ?? this.bio,
    interests: interests ?? this.interests,
    role: role,
    status: status ?? this.status,
    profileComplete: profileComplete ?? this.profileComplete,
    hostReviewed: hostReviewed ?? this.hostReviewed,
    pausedUntil: pausedUntil ?? this.pausedUntil,
    lateCancels: lateCancels ?? this.lateCancels,
  );
}

class Gathering {
  final String id;
  final String hostId;
  final String theme;
  final String activity;
  final String description;
  final String area;
  final String address;
  final DateTime start;
  final int seatCap;
  final List<String> rules;
  final bool cancelled;

  const Gathering({
    required this.id,
    required this.hostId,
    required this.theme,
    required this.activity,
    required this.description,
    required this.area,
    required this.address,
    required this.start,
    required this.seatCap,
    required this.rules,
    this.cancelled = false,
  });

  bool get isPast => start.isBefore(DateTime.now());

  DateTime get addressUnlockAt => start.subtract(const Duration(hours: 2));

  Gathering copyWith({bool? cancelled}) => Gathering(
    id: id,
    hostId: hostId,
    theme: theme,
    activity: activity,
    description: description,
    area: area,
    address: address,
    start: start,
    seatCap: seatCap,
    rules: rules,
    cancelled: cancelled ?? this.cancelled,
  );
}

class SeatRequest {
  final String id;
  final String gatheringId;
  final String userId;
  final String note;
  final SeatStatus status;
  final DateTime createdAt;
  final DateTime? rulesAcceptedAt;

  const SeatRequest({
    required this.id,
    required this.gatheringId,
    required this.userId,
    required this.note,
    required this.status,
    required this.createdAt,
    this.rulesAcceptedAt,
  });

  bool get holdsSeat => status == SeatStatus.approved;
  bool get confirmed => holdsSeat && rulesAcceptedAt != null;

  SeatRequest copyWith({SeatStatus? status, DateTime? rulesAcceptedAt}) =>
      SeatRequest(
        id: id,
        gatheringId: gatheringId,
        userId: userId,
        note: note,
        status: status ?? this.status,
        createdAt: createdAt,
        rulesAcceptedAt: rulesAcceptedAt ?? this.rulesAcceptedAt,
      );
}

class Attendance {
  final String gatheringId;
  final String userId;
  final bool attended;
  const Attendance(this.gatheringId, this.userId, this.attended);
}

class SessionFeedback {
  final String gatheringId;
  final String userId;
  final int safety;
  final int welcome;
  final String comment;
  const SessionFeedback(
    this.gatheringId,
    this.userId,
    this.safety,
    this.welcome,
    this.comment,
  );
}

class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String? gatheringId;
  final String reason;
  const Report(
    this.id,
    this.reporterId,
    this.reportedUserId,
    this.gatheringId,
    this.reason,
  );
}

class Notice {
  final String userId;
  final String title;
  final String body;
  final DateTime at;
  const Notice(this.userId, this.title, this.body, this.at);
}
