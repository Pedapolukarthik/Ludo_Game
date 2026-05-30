import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/mission_model.dart';

class DailyMissionsNotifier extends StateNotifier<AsyncValue<List<MissionModel>>> {
  DailyMissionsNotifier() : super(const AsyncValue.loading()) {
    fetchMissions();
  }

  Future<void> fetchMissions() async {
    try {
      final response = await ApiClient.get('/rewards/missions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('missions') && data['missions'] is List) {
          final list = (data['missions'] as List)
              .map((m) => MissionModel.fromJson(m))
              .toList();
          state = AsyncValue.data(list);
        } else {
          String errorMsg = 'Invalid daily missions response format';
          if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'];
          }
          state = AsyncValue.error(errorMsg, StackTrace.current);
        }
      } else {
        String errorMsg = 'Failed to load daily missions (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'];
          }
        } catch (_) {}
        state = AsyncValue.error(errorMsg, StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final dailyMissionsProvider = StateNotifierProvider<DailyMissionsNotifier, AsyncValue<List<MissionModel>>>((ref) {
  return DailyMissionsNotifier();
});
