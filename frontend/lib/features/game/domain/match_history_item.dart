class MatchHistoryItem {
  final String id;
  final String roomCode;
  final List<MatchPlayer> players;
  final MatchWinner winner;
  final int entryFee;
  final int prizePool;
  final DateTime createdAt;

  MatchHistoryItem({
    required this.id,
    required this.roomCode,
    required this.players,
    required this.winner,
    required this.entryFee,
    required this.prizePool,
    required this.createdAt,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      id: json['_id'] ?? json['id'] ?? '',
      roomCode: json['roomCode'] ?? '',
      players: (json['players'] as List?)
              ?.map((p) => MatchPlayer.fromJson(p))
              .toList() ??
          [],
      winner: MatchWinner.fromJson(json['winner'] ?? {}),
      entryFee: json['entryFee'] ?? 0,
      prizePool: json['prizePool'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class MatchPlayer {
  final String? userId;
  final String name;
  final String avatar;
  final String color;
  final bool isBot;

  MatchPlayer({
    this.userId,
    required this.name,
    required this.avatar,
    required this.color,
    required this.isBot,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    return MatchPlayer(
      userId: json['user']?.toString(),
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      color: json['color'] ?? '',
      isBot: json['isBot'] ?? false,
    );
  }
}

class MatchWinner {
  final String? userId;
  final String name;

  MatchWinner({
    this.userId,
    required this.name,
  });

  factory MatchWinner.fromJson(Map<String, dynamic> json) {
    return MatchWinner(
      userId: json['user']?.toString(),
      name: json['name'] ?? 'Unknown',
    );
  }
}
