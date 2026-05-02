import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/v2/auth_screen.dart';
import 'screens/v2/shell_scaffold.dart';
import 'screens/v2/home_screen.dart';
import 'screens/v2/pool_screen.dart';
import 'screens/v2/task_detail_screen.dart';
import 'screens/v2/record_screen.dart';
import 'screens/v2/success_screen.dart';
import 'screens/v2/submissions_screen.dart';
import 'screens/v2/submission_detail_screen.dart';
import 'screens/v2/profile_screen.dart';
import 'screens/v2/settings_screen.dart';
import 'state/auth_controller.dart';

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/auth',
    // refreshListenable + redirect together act as the auth gate: every time
    // the AuthController notifies, redirect re-runs and may bounce the user.
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final atAuth = state.matchedLocation == '/auth';
      if (!loggedIn && !atAuth) return '/auth';
      if (loggedIn && atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/submissions',
            pageBuilder: (_, __) => const NoTransitionPage(child: SubmissionsScreen()),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/pool/:categoryId',
        builder: (_, state) => PoolScreen(categoryId: state.pathParameters['categoryId']!),
      ),
      GoRoute(
        path: '/task/:taskId',
        builder: (_, state) => TaskDetailScreen(taskId: state.pathParameters['taskId']!),
      ),
      GoRoute(
        path: '/record/:taskId',
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: RecordScreen(taskId: state.pathParameters['taskId']!),
        ),
      ),
      GoRoute(
        path: '/success',
        builder: (_, state) {
          final pts = int.tryParse(state.uri.queryParameters['points'] ?? '') ?? 0;
          return SuccessScreen(points: pts);
        },
      ),
      GoRoute(
        path: '/submissions/:sessionId',
        builder: (_, state) => SubmissionDetailScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(path: '/me/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}
