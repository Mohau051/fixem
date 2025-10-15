import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String id;
  final String badgeTitle;
  final String courseTitle;
  final String courseId;
  final DateTime awardedAt;
  final String description;
  final String duration;
  final String matchedJobs;

  Badge({
    required this.id,
    required this.badgeTitle,
    required this.courseTitle,
    required this.courseId,
    required this.awardedAt,
    required this.description,
    required this.duration,
    required this.matchedJobs,
  });

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Badge(
      id: doc.id,
      badgeTitle: data['badgeTitle'] ?? '',
      courseTitle: data['courseTitle'] ?? '',
      courseId: data['courseId'] ?? '',
      awardedAt: (data['awardedAt'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      duration: data['duration'] ?? '',
      matchedJobs: data['matchedJobs'] ?? '',
    );
  }
}
