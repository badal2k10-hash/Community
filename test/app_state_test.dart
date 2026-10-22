import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community/data/app_state.dart';
import 'package:community/data/models.dart';

void main() {
  late ProviderContainer c;
  late AppController ctrl;

  setUp(() {
    c = ProviderContainer();
    ctrl = c.read(appProvider.notifier);
  });
  tearDown(() => c.dispose());

  AppState s() => c.read(appProvider);

  test('login with demo OTP signs in the seeded attendee', () {
    expect(ctrl.verifyOtp(demoAttendeePhone, '000000'), isNotNull);
    expect(ctrl.verifyOtp(demoAttendeePhone, demoOtp), isNull);
    expect(s().me!.firstName, 'Meera');
  });

  test('seat cap is enforced and waitlist promotes on cancel', () {
    ctrl.verifyOtp(demoHostPhone, demoOtp);
    ctrl.createGathering(
      theme: 't',
      activity: 'a',
      description: 'd',
      area: 'x',
      address: 'y',
      start: DateTime.now().add(const Duration(days: 5)),
      seats: 1,
      rules: defaultRules,
    );
    final g = s().gatherings.last;
    ctrl.signOut();

    ctrl.verifyOtp(demoAttendeePhone, demoOtp);
    expect(ctrl.requestSeat(g.id, 'I would like to come.'), isNull);
    final first = s().myRequest(g.id)!;
    ctrl.signOut();

    ctrl.verifyOtp('8000000000', demoOtp);
    ctrl.saveProfile(firstName: 'N', ageRange: '25-34', bio: '', interests: []);
    ctrl.requestSeat(g.id, 'I would like to come.');
    final second = s().myRequest(g.id)!;
    ctrl.signOut();

    ctrl.verifyOtp(demoHostPhone, demoOtp);
    expect(ctrl.approve(first.id), isNull);
    expect(ctrl.approve(second.id), isNotNull);
    expect(s().held(g.id), 1);
    ctrl.signOut();

    ctrl.verifyOtp(demoAttendeePhone, demoOtp);
    ctrl.cancelRequest(first.id);
    expect(
      s().requests.firstWhere((r) => r.id == second.id).status,
      SeatStatus.approved,
    );
  });

  test('two independent reports pause the user', () {
    ctrl.verifyOtp(demoAttendeePhone, demoOtp);
    ctrl.reportUser('u0', null, 'x');
    expect(s().users['u0']!.status, UserStatus.active);
    ctrl.signOut();
    ctrl.verifyOtp(demoHostPhone, demoOtp);
    ctrl.reportUser('u0', null, 'x');
    expect(s().users['u0']!.status, UserStatus.paused);
  });

  test('three no-shows pause requests for 30 days', () {
    for (final g in ['a', 'b', 'c']) {
      ctrl.markAttendance(g, 'u1', false);
    }
    expect(s().users['u1']!.isPaused, isTrue);
  });
}
