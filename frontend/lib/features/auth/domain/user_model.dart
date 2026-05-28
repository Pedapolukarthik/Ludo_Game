class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final int coins;
  final int xp;
  final int level;
  final String rank;
  final int totalWins;
  final int totalGames;
  final int loginStreak;
  final List<String> achievements;
  final String referralCode;
  final List<String> friends;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.coins,
    required this.xp,
    required this.level,
    required this.rank,
    required this.totalWins,
    required this.totalGames,
    required this.loginStreak,
    required this.achievements,
    required this.referralCode,
    required this.friends,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      coins: json['coins'] ?? 0,
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      rank: json['rank'] ?? 'Bronze',
      totalWins: json['totalWins'] ?? 0,
      totalGames: json['totalGames'] ?? 0,
      loginStreak: json['loginStreak'] ?? 1,
      achievements: List<String>.from(json['achievements'] ?? []),
      referralCode: json['referralCode'] ?? '',
      friends: List<String>.from(
        (json['friends'] as List?)?.map((e) => e is Map ? (e['_id'] ?? '') : e.toString()) ?? []
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'coins': coins,
      'xp': xp,
      'level': level,
      'rank': rank,
      'totalWins': totalWins,
      'totalGames': totalGames,
      'loginStreak': loginStreak,
      'achievements': achievements,
      'referralCode': referralCode,
      'friends': friends,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    int? coins,
    int? xp,
    int? level,
    String? rank,
    int? totalWins,
    int? totalGames,
    int? loginStreak,
    List<String>? achievements,
    String? referralCode,
    List<String>? friends,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      totalWins: totalWins ?? this.totalWins,
      totalGames: totalGames ?? this.totalGames,
      loginStreak: loginStreak ?? this.loginStreak,
      achievements: achievements ?? this.achievements,
      referralCode: referralCode ?? this.referralCode,
      friends: friends ?? this.friends,
    );
  }
}
