class Category {
  final String id;
  final String title;
  final int taskCount;
  final int? rewardPoints;
  final bool soon;
  final bool tall;

  const Category({
    required this.id,
    required this.title,
    required this.taskCount,
    this.rewardPoints,
    this.soon = false,
    this.tall = false,
  });
}

class Task {
  final String id;
  final String categoryId;
  final String tag;
  final String title;
  final String publisher;
  final int rewardPoints;
  final String duration;
  final String slots;
  final String difficulty;
  final String lighting;
  final String surface;
  final List<String> steps;

  const Task({
    required this.id,
    required this.categoryId,
    required this.tag,
    required this.title,
    required this.publisher,
    required this.rewardPoints,
    required this.duration,
    required this.slots,
    required this.difficulty,
    required this.lighting,
    required this.surface,
    required this.steps,
  });
}

class Profile {
  final String displayName;
  final String uid;
  final int balancePoints;
  final int pendingPoints;
  final double hoursLogged;
  final int submittedCount;
  final double approvalRate;
  final List<double> capabilities;

  const Profile({
    required this.displayName,
    required this.uid,
    required this.balancePoints,
    required this.pendingPoints,
    required this.hoursLogged,
    required this.submittedCount,
    required this.approvalRate,
    required this.capabilities,
  });
}

class LeaderRow {
  final int rank;
  final String name;
  final double hours;
  final int points;
  final bool isYou;

  const LeaderRow({
    required this.rank,
    required this.name,
    required this.hours,
    required this.points,
    this.isYou = false,
  });
}
