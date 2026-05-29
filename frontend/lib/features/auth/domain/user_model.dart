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
  final bool banned;
  final int losses;
  final int currentWinStreak;
  final int highestWinStreak;

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
    this.banned = false,
    this.losses = 0,
    this.currentWinStreak = 0,
    this.highestWinStreak = 0,
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
      banned: json['banned'] ?? false,
      losses: json['losses'] ?? 0,
      currentWinStreak: json['currentWinStreak'] ?? 0,
      highestWinStreak: json['highestWinStreak'] ?? 0,
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
      'banned': banned,
      'losses': losses,
      'currentWinStreak': currentWinStreak,
      'highestWinStreak': highestWinStreak,
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
    bool? banned,
    int? losses,
    int? currentWinStreak,
    int? highestWinStreak,
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
      banned: banned ?? this.banned,
      losses: losses ?? this.losses,
      currentWinStreak: currentWinStreak ?? this.currentWinStreak,
      highestWinStreak: highestWinStreak ?? this.highestWinStreak,
    );
  }

  bool get isAdmin => email.contains('admin') || email == 'admin@ludopremium.com' || email == 'admin@example.com';
}
