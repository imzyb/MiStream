import 'dart:async';

/// Recommendation engine that suggests content based on user behavior.
///
/// Uses viewing history, favorites, and category preferences
/// to generate personalized recommendations.
class RecommendationEngine {
  RecommendationEngine({
    required this.historySource,
    required this.favoriteSource,
  });

  /// Source for viewing history.
  final HistorySource historySource;

  /// Source for favorites.
  final FavoriteSource favoriteSource;

  /// Generate recommendations for the user.
  Future<List<Recommendation>> getRecommendations({int limit = 20}) async {
    final history = await historySource.getRecent(limit: 100);
    final favorites = await favoriteSource.getAll();

    // Analyze viewing patterns
    final categoryScores = _analyzeCategoryPreferences(history);
    _analyzeRecentTypes(history);

    // Generate recommendations based on preferences
    final recommendations = <Recommendation>[];

    // Add category-based recommendations
    for (final entry in categoryScores.entries) {
      recommendations.add(
        Recommendation(
          id: 'cat_${entry.key}',
          title: entry.key,
          reason: 'Based on your interest in ${entry.key}',
          score: entry.value,
          type: RecommendationType.category,
        ),
      );
    }

    // Add "continue watching" recommendations
    for (final item in history.where((h) => !h.finished).take(5)) {
      recommendations.add(
        Recommendation(
          id: 'continue_${item.vodId}',
          title: item.vodName,
          reason: 'Continue watching',
          score: 1,
          type: RecommendationType.continueWatching,
          data: {'vodId': item.vodId, 'progress': item.progress},
        ),
      );
    }

    // Add "because you liked" recommendations
    if (favorites.isNotEmpty) {
      final topFavorite = favorites.first;
      recommendations.add(
        Recommendation(
          id: 'similar_${topFavorite.vodId}',
          title: 'Similar to ${topFavorite.vodName}',
          reason: 'Because you liked ${topFavorite.vodName}',
          score: 0.8,
          type: RecommendationType.similar,
        ),
      );
    }

    // Sort by score and limit
    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(limit).toList();
  }

  /// Analyze category preferences from viewing history.
  Map<String, double> _analyzeCategoryPreferences(List<HistoryEntry> history) {
    final scores = <String, double>{};
    for (final entry in history) {
      final category = entry.category ?? 'Unknown';
      scores[category] = (scores[category] ?? 0) + 1.0;
    }

    // Normalize scores
    final maxScore = scores.values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxScore > 0) {
      for (final key in scores.keys) {
        scores[key] = scores[key]! / maxScore;
      }
    }

    return scores;
  }

  /// Analyze recently watched content types.
  Map<String, double> _analyzeRecentTypes(List<HistoryEntry> history) {
    final scores = <String, double>{};
    for (final entry in history.take(20)) {
      final type = entry.contentType ?? 'movie';
      scores[type] = (scores[type] ?? 0) + 1.0;
    }
    return scores;
  }
}

/// Types of recommendations.
enum RecommendationType {
  category,
  continueWatching,
  similar,
  trending,
  newRelease,
}

/// A content recommendation.
class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.reason,
    required this.score,
    required this.type,
    this.data,
  });

  final String id;
  final String title;
  final String reason;
  final double score;
  final RecommendationType type;
  final Map<String, dynamic>? data;
}

/// Abstract interface for history data source.
abstract class HistorySource {
  Future<List<HistoryEntry>> getRecent({int limit = 50});
}

/// Abstract interface for favorites data source.
abstract class FavoriteSource {
  Future<List<FavoriteEntry>> getAll();
}

/// A history entry.
class HistoryEntry {
  const HistoryEntry({
    required this.vodId,
    required this.vodName,
    this.category,
    this.contentType,
    this.finished = false,
    this.progress = 0,
  });

  final String vodId;
  final String vodName;
  final String? category;
  final String? contentType;
  final bool finished;
  final double progress;
}

/// A favorite entry.
class FavoriteEntry {
  const FavoriteEntry({
    required this.vodId,
    required this.vodName,
    this.vodPic,
  });

  final String vodId;
  final String vodName;
  final String? vodPic;
}
