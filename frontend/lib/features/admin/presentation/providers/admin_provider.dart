import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

class AdminState {
  final AdminAnalytics? analytics;
  final List<UserModel> users;
  final int usersTotalCount;
  final int usersCurrentPage;
  final List<ActiveMatch> activeMatches;
  final List<MatchHistory> matchHistory;
  final int historyTotalCount;
  final int historyCurrentPage;
  final List<TournamentModel> tournaments;
  
  final bool isAnalyticsLoading;
  final bool isUsersLoading;
  final bool isMatchesLoading;
  final bool isTournamentsLoading;
  final bool isActionPending;
  final String? errorMessage;
  final String? successMessage;

  AdminState({
    this.analytics,
    this.users = const [],
    this.usersTotalCount = 0,
    this.usersCurrentPage = 1,
    this.activeMatches = const [],
    this.matchHistory = const [],
    this.historyTotalCount = 0,
    this.historyCurrentPage = 1,
    this.tournaments = const [],
    this.isAnalyticsLoading = false,
    this.isUsersLoading = false,
    this.isMatchesLoading = false,
    this.isTournamentsLoading = false,
    this.isActionPending = false,
    this.errorMessage,
    this.successMessage,
  });

  AdminState copyWith({
    AdminAnalytics? analytics,
    List<UserModel>? users,
    int? usersTotalCount,
    int? usersCurrentPage,
    List<ActiveMatch>? activeMatches,
    List<MatchHistory>? matchHistory,
    int? historyTotalCount,
    int? historyCurrentPage,
    List<TournamentModel>? tournaments,
    bool? isAnalyticsLoading,
    bool? isUsersLoading,
    bool? isMatchesLoading,
    bool? isTournamentsLoading,
    bool? isActionPending,
    String? errorMessage,
    String? successMessage,
  }) {
    return AdminState(
      analytics: analytics ?? this.analytics,
      users: users ?? this.users,
      usersTotalCount: usersTotalCount ?? this.usersTotalCount,
      usersCurrentPage: usersCurrentPage ?? this.usersCurrentPage,
      activeMatches: activeMatches ?? this.activeMatches,
      matchHistory: matchHistory ?? this.matchHistory,
      historyTotalCount: historyTotalCount ?? this.historyTotalCount,
      historyCurrentPage: historyCurrentPage ?? this.historyCurrentPage,
      tournaments: tournaments ?? this.tournaments,
      isAnalyticsLoading: isAnalyticsLoading ?? this.isAnalyticsLoading,
      isUsersLoading: isUsersLoading ?? this.isUsersLoading,
      isMatchesLoading: isMatchesLoading ?? this.isMatchesLoading,
      isTournamentsLoading: isTournamentsLoading ?? this.isTournamentsLoading,
      isActionPending: isActionPending ?? this.isActionPending,
      errorMessage: errorMessage, // Reset or assign new error
      successMessage: successMessage, // Reset or assign new success
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final AdminRepository _repository;
  final Ref _ref;

  AdminNotifier(this._repository, this._ref) : super(AdminState());

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  Future<void> fetchAll() async {
    await Future.wait([
      getAnalytics(),
      getUsers(page: 1),
      getActiveMatches(),
      getMatchHistory(page: 1),
      getTournaments(),
    ]);
  }

  Future<void> getAnalytics() async {
    state = state.copyWith(isAnalyticsLoading: true, errorMessage: null);
    try {
      final analytics = await _repository.getAnalytics();
      state = state.copyWith(analytics: analytics, isAnalyticsLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isAnalyticsLoading: false);
    }
  }

  Future<void> getUsers({int page = 1}) async {
    state = state.copyWith(isUsersLoading: true, errorMessage: null);
    try {
      final result = await _repository.getUsers(page: page, limit: 10);
      state = state.copyWith(
        users: result['users'],
        usersTotalCount: result['total'],
        usersCurrentPage: page,
        isUsersLoading: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isUsersLoading: false);
    }
  }

  Future<void> getActiveMatches() async {
    state = state.copyWith(isMatchesLoading: true, errorMessage: null);
    try {
      final active = await _repository.getActiveMatches();
      state = state.copyWith(activeMatches: active, isMatchesLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isMatchesLoading: false);
    }
  }

  Future<void> getMatchHistory({int page = 1}) async {
    state = state.copyWith(isMatchesLoading: true, errorMessage: null);
    try {
      final result = await _repository.getMatchHistory(page: page, limit: 10);
      state = state.copyWith(
        matchHistory: result['matches'],
        historyTotalCount: result['total'],
        historyCurrentPage: page,
        isMatchesLoading: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isMatchesLoading: false);
    }
  }

  Future<void> getTournaments() async {
    state = state.copyWith(isTournamentsLoading: true, errorMessage: null);
    try {
      final tournaments = await _repository.getTournaments();
      state = state.copyWith(tournaments: tournaments, isTournamentsLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isTournamentsLoading: false);
    }
  }

  Future<bool> toggleBanUser(String userId, bool ban) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      final updatedUser = await _repository.toggleBan(userId, ban);
      
      // Update local user list
      final updatedUsers = state.users.map((u) {
        return u.id == userId ? updatedUser : u;
      }).toList();

      state = state.copyWith(
        users: updatedUsers,
        isActionPending: false,
        successMessage: ban ? 'User banned successfully.' : 'User unbanned successfully.',
      );
      
      // Refresh analytics in background
      getAnalytics();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }

  Future<bool> adjustUserCoins(String userId, int coins, int xp) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      final updatedUserRaw = await _repository.adjustCoins(userId, coins: coins, xp: xp);
      
      // Update in user list
      final updatedUsers = state.users.map((u) {
        if (u.id == userId) {
          return u.copyWith(
            coins: updatedUserRaw['coins'],
            xp: updatedUserRaw['xp'],
          );
        }
        return u;
      }).toList();

      state = state.copyWith(
        users: updatedUsers,
        isActionPending: false,
        successMessage: 'User rewards adjusted successfully.',
      );

      // If the current user logged in is the one modified, we also trigger profile update
      final currentUserId = _ref.read(authProvider).user?.id;
      if (currentUserId == userId) {
        _ref.read(authProvider.notifier).tryRestoreSession();
      }

      getAnalytics();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }

  Future<bool> createTournament({
    required String title,
    required int entryFee,
    required int prizePool,
    required DateTime startTime,
  }) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      final tournament = await _repository.createTournament(
        title: title,
        entryFee: entryFee,
        prizePool: prizePool,
        startTime: startTime,
      );
      state = state.copyWith(
        tournaments: [...state.tournaments, tournament],
        isActionPending: false,
        successMessage: 'Tournament created successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }

  Future<bool> updateTournamentStatus(String id, String status) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      final updated = await _repository.updateTournament(id, status: status);
      final updatedList = state.tournaments.map((t) => t.id == id ? updated : t).toList();
      state = state.copyWith(
        tournaments: updatedList,
        isActionPending: false,
        successMessage: 'Tournament status updated to $status.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }

  Future<bool> deleteTournament(String id) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      await _repository.deleteTournament(id);
      final updatedList = state.tournaments.where((t) => t.id != id).toList();
      state = state.copyWith(
        tournaments: updatedList,
        isActionPending: false,
        successMessage: 'Tournament deleted successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }

  Future<bool> broadcastNotification(String title, String body) async {
    state = state.copyWith(isActionPending: true, errorMessage: null, successMessage: null);
    try {
      await _repository.broadcastNotification(title, body);
      state = state.copyWith(
        isActionPending: false,
        successMessage: 'System alert broadcast successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isActionPending: false);
      return false;
    }
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return AdminNotifier(repository, ref);
});
