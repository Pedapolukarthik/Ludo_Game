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
        final list = (data['missions'] as List)
            .map((m) => MissionModel.fromJson(m))
            .toList();
        state = AsyncValue.data(list);
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to load daily missions';
        state = AsyncValue.error(error, StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final dailyMissionsProvider = StateNotifierProvider<DailyMissionsNotifier, AsyncValue<List<MissionModel>>>((ref) {
  return DailyMissionsNotifier();
});
