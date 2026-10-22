import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/app_state.dart';
import 'data/models.dart';
import 'screens/attendee.dart';
import 'screens/host.dart';
import 'screens/onboarding.dart';
import 'screens/shared.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(appProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final me = ref.read(appProvider).me;
    final loc = state.uri.path;
    final onboarding = loc == '/welcome' || loc == '/login';
    if (me == null) {
      if (loc == '/welcome') return null;
      if (loc == '/login') return null;
      return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    if (!me.profileComplete) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }
    if (onboarding || loc == '/profile-setup') {
      return state.uri.queryParameters['from'] ?? '/home';
    }
    if (loc.startsWith('/host') && me.role != Role.host) return '/home';
    return null;
  }

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/profile-setup', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/profile-edit',
        builder: (_, _) => const ProfileScreen(editing: true),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/mine', builder: (_, _) => const MyGatheringsScreen()),
          GoRoute(
            path: '/resources',
            builder: (_, _) => const ResourcesScreen(),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/host', builder: (_, _) => const HostHomeScreen()),
        ],
      ),
      GoRoute(
        path: '/g/:id',
        builder: (_, s) => GatheringDetailScreen(id: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'request',
            builder: (_, s) => RequestSeatScreen(id: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/ticket/:id',
        builder: (_, s) => TicketScreen(requestId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/feedback/:id',
        builder: (_, s) => FeedbackScreen(gatheringId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/notices', builder: (_, _) => const NoticesScreen()),
      GoRoute(
        path: '/host/create',
        builder: (_, _) => const CreateGatheringScreen(),
      ),
      GoRoute(
        path: '/host/g/:id',
        builder: (_, s) =>
            DashboardScreen(gatheringId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'requests',
            builder: (_, s) =>
                RequestsScreen(gatheringId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

class _Shell extends ConsumerWidget {
  final String location;
  final Widget child;
  const _Shell({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHost = ref.watch(appProvider).me?.role == Role.host;
    final tabs = [
      ('/home', Icons.home_outlined, 'Home'),
      ('/mine', Icons.event_seat_outlined, 'My gatherings'),
      if (isHost) ('/host', Icons.groups_outlined, 'Host'),
      ('/resources', Icons.favorite_border, 'Support'),
      ('/settings', Icons.settings_outlined, 'Settings'),
    ];
    final index = tabs.indexWhere((t) => location.startsWith(t.$1));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].$1),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.$2), label: t.$3),
        ],
      ),
    );
  }
}

class BaithakApp extends ConsumerWidget {
  const BaithakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Baithak',
    routerConfig: ref.watch(routerProvider),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D5A97)),
      useMaterial3: true,
    ),
  );
}
