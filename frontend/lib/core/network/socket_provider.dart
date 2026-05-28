import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  
  // Make sure it disconnects when provider is disposed
  ref.onDispose(() {
    service.disconnect();
  });
  
  return service;
});
