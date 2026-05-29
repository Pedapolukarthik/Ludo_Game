import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/settings_screen.dart';
import '../../features/game/presentation/screens/home_screen.dart';
import '../../features/game/presentation/screens/lobby_screen.dart';
import '../../features/game/presentation/screens/game_room_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/rewards/presentation/screens/rewards_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/game/presentation/screens/match_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LobbyScreen(
            roomCode: extra?['roomCode'] as String? ?? '',
            isHost: extra?['isHost'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return GameRoomScreen(
            roomCode: extra?['roomCode'] as String? ?? '',
            initialGameState: extra?['gameState'] as Map<String, dynamic>? ?? {},
          );
        },
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/match-history',
        builder: (context, state) => const MatchHistoryScreen(),
      ),
    ],
  );
});
