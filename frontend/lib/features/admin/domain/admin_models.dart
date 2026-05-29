class AdminAnalytics {
  final int totalUsers;
  final int totalMatches;
  final int totalActiveRooms;
  final int activeCoinsInEconomy;

  AdminAnalytics({
    required this.totalUsers,
    required this.totalMatches,
    required this.totalActiveRooms,
    required this.activeCoinsInEconomy,
  });

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      totalUsers: json['totalUsers'] ?? 0,
      totalMatches: json['totalMatches'] ?? 0,
      totalActiveRooms: json['totalActiveRooms'] ?? 0,
      activeCoinsInEconomy: json['activeCoinsInEconomy'] ?? 0,
    );
  }
}

class ActiveMatch {
  final String roomCode;
  final List<ActiveMatchPlayer> players;
  final List<String> colors;
  final String activeColor;
  final int? diceValue;
  final String rollState;
  final String? winner;

  ActiveMatch({
    required this.roomCode,
    required this.players,
    required this.colors,
    required this.activeColor,
    this.diceValue,
    required this.rollState,
    this.winner,
  });

  factory ActiveMatch.fromJson(Map<String, dynamic> json) {
    return ActiveMatch(
      roomCode: json['roomCode'] ?? '',
      players: (json['players'] as List?)?.map((p) => ActiveMatchPlayer.fromJson(p)).toList() ?? [],
      colors: List<String>.from(json['colors'] ?? []),
      activeColor: json['activeColor'] ?? '',
      diceValue: json['diceValue'],
      rollState: json['rollState'] ?? 'idle',
      winner: json['winner'],
    );
  }
}

class ActiveMatchPlayer {
  final String? userId;
  final String name;
  final String avatar;
  final String color;
  final bool isBot;
  final bool active;

  ActiveMatchPlayer({
    this.userId,
    required this.name,
    required this.avatar,
    required this.color,
    required this.isBot,
    required this.active,
  });

  factory ActiveMatchPlayer.fromJson(Map<String, dynamic> json) {
    return ActiveMatchPlayer(
      userId: json['userId'],
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      color: json['color'] ?? '',
      isBot: json['isBot'] ?? false,
      active: json['active'] ?? true,
    );
  }
}

class MatchHistory {
  final String id;
  final String roomCode;
  final List<MatchHistoryPlayer> players;
  final String winnerName;
  final int entryFee;
  final int prizePool;
  final DateTime createdAt;

  MatchHistory({
    required this.id,
    required this.roomCode,
    required this.players,
    required this.winnerName,
    required this.entryFee,
    required this.prizePool,
    required this.createdAt,
  });

  factory MatchHistory.fromJson(Map<String, dynamic> json) {
    return MatchHistory(
      id: json['_id'] ?? json['id'] ?? '',
      roomCode: json['roomCode'] ?? '',
      players: (json['players'] as List?)?.map((p) => MatchHistoryPlayer.fromJson(p)).toList() ?? [],
      winnerName: json['winner'] is Map ? (json['winner']['name'] ?? 'Unknown') : (json['winnerName'] ?? 'Unknown'),
      entryFee: json['entryFee'] ?? 0,
      prizePool: json['prizePool'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class MatchHistoryPlayer {
  final String? userId;
  final String name;
  final String avatar;
  final String color;
  final bool isBot;

  MatchHistoryPlayer({
    this.userId,
    required this.name,
    required this.avatar,
    required this.color,
    required this.isBot,
  });

  factory MatchHistoryPlayer.fromJson(Map<String, dynamic> json) {
    return MatchHistoryPlayer(
      userId: json['user'] is Map ? json['user']['_id'] : json['user']?.toString(),
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      color: json['color'] ?? '',
      isBot: json['isBot'] ?? false,
    );
  }
}

class TournamentModel {
  final String id;
  final String title;
  final int entryFee;
  final int prizePool;
  final DateTime startTime;
  final String status;
  final int participantCount;
  final String? winnerId;

  TournamentModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.prizePool,
    required this.startTime,
    required this.status,
    required this.participantCount,
    this.winnerId,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      entryFee: json['entryFee'] ?? 0,
      prizePool: json['prizePool'] ?? 0,
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'upcoming',
      participantCount: (json['participants'] as List?)?.length ?? 0,
      winnerId: json['winner'] is Map ? json['winner']['_id'] : json['winner']?.toString(),
    );
  }
}
