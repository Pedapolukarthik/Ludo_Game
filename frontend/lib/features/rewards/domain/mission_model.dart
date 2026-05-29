class MissionModel {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int goal;
  final int coins;
  final int xp;
  final bool completed;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.goal,
    required this.coins,
    required this.xp,
    required this.completed,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      progress: json['progress'] ?? 0,
      goal: json['goal'] ?? 0,
      coins: json['coins'] ?? 0,
      xp: json['xp'] ?? 0,
      completed: json['completed'] ?? false,
    );
  }
}
