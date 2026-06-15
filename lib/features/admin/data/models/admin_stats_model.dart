// lib/screens/admin/data/models/admin_stats_model.dart

class AdminStatsModel {
  final int totalUsers;
  final int totalPosts;
  final int totalStories;
  final int totalFestas;
  final int pendingReports;

  const AdminStatsModel({
    required this.totalUsers,
    required this.totalPosts,
    required this.totalStories,
    required this.totalFestas,
    required this.pendingReports,
  });

  const AdminStatsModel.empty()
      : totalUsers     = 0,
        totalPosts     = 0,
        totalStories   = 0,
        totalFestas    = 0,
        pendingReports = 0;
}

