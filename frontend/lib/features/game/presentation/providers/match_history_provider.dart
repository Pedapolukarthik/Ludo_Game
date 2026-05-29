import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/match_history_item.dart';

class MatchHistoryNotifier extends StateNotifier<AsyncValue<List<MatchHistoryItem>>> {
  MatchHistoryNotifier() : super(const AsyncValue.loading()) {
    fetchMatchHistory();
  }

  Future<void> fetchMatchHistory() async {
    try {
      final response = await ApiClient.get('/users/match-history');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['matches'] as List)
            .map((m) => MatchHistoryItem.fromJson(m))
            .toList();
        state = AsyncValue.data(list);
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to load match history';
        state = AsyncValue.error(error, StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final matchHistoryProvider = StateNotifierProvider<MatchHistoryNotifier, AsyncValue<List<MatchHistoryItem>>>((ref) {
  return MatchHistoryNotifier();
});
