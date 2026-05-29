import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../auth/domain/user_model.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  Future<AdminAnalytics> getAnalytics() async {
    final response = await ApiClient.get('/admin/analytics');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AdminAnalytics.fromJson(data['analytics']);
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to load analytics';
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> getUsers({int page = 1, int limit = 10}) async {
    final response = await ApiClient.get('/admin/users?page=$page&limit=$limit');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final usersList = (data['users'] as List)
          .map((u) => UserModel.fromJson(u))
          .toList();
      final total = data['pagination']['total'] ?? usersList.length;
      return {
        'users': usersList,
        'total': total,
      };
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to load users';
      throw Exception(error);
    }
  }

  Future<UserModel> toggleBan(String userId, bool ban) async {
    final response = await ApiClient.put('/admin/users/$userId/ban', {'ban': ban});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson(data['user']);
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to toggle ban status';
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> adjustCoins(String userId, {int? coins, int? xp}) async {
    final response = await ApiClient.put('/admin/users/$userId/reward', {
      if (coins != null) 'coins': coins,
      if (xp != null) 'xp': xp,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user'];
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to adjust user coins/XP';
      throw Exception(error);
    }
  }

  Future<List<ActiveMatch>> getActiveMatches() async {
    final response = await ApiClient.get('/admin/matches/active');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['activeMatches'] as List)
          .map((m) => ActiveMatch.fromJson(m))
          .toList();
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to load active matches';
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> getMatchHistory({int page = 1, int limit = 10}) async {
    final response = await ApiClient.get('/admin/matches/history?page=$page&limit=$limit');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['matches'] as List)
          .map((m) => MatchHistory.fromJson(m))
          .toList();
      final total = data['pagination']['total'] ?? list.length;
      return {
        'matches': list,
        'total': total,
      };
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to load match history';
      throw Exception(error);
    }
  }

  Future<List<TournamentModel>> getTournaments() async {
    // Note: Tournaments list endpoint is public on /tournaments
    final response = await ApiClient.get('/tournaments');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tournaments'] as List)
          .map((t) => TournamentModel.fromJson(t))
          .toList();
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to load tournaments';
      throw Exception(error);
    }
  }

  Future<TournamentModel> createTournament({
    required String title,
    required int entryFee,
    required int prizePool,
    required DateTime startTime,
  }) async {
    // Note: Create tournament is public/admin on /tournaments/create
    final response = await ApiClient.post('/tournaments/create', {
      'title': title,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'startTime': startTime.toIso8601String(),
    });
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return TournamentModel.fromJson(data['tournament']);
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to create tournament';
      throw Exception(error);
    }
  }

  Future<TournamentModel> updateTournament(
    String id, {
    String? title,
    int? entryFee,
    int? prizePool,
    DateTime? startTime,
    String? status,
  }) async {
    final response = await ApiClient.put('/admin/tournaments/$id', {
      if (title != null) 'title': title,
      if (entryFee != null) 'entryFee': entryFee,
      if (prizePool != null) 'prizePool': prizePool,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (status != null) 'status': status,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TournamentModel.fromJson(data['tournament']);
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to update tournament';
      throw Exception(error);
    }
  }

  Future<void> deleteTournament(String id) async {
    final response = await ApiClient.delete('/admin/tournaments/$id');
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to delete tournament';
      throw Exception(error);
    }
  }

  Future<void> broadcastNotification(String title, String body) async {
    final response = await ApiClient.post('/admin/broadcast', {
      'title': title,
      'body': body,
    });
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['message'] ?? 'Failed to send broadcast notification';
      throw Exception(error);
    }
  }
}
