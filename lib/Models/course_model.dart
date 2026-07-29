class Course {
  final String id;
  final String title;
  final int duration;
  final String badge;
  final List<String> matchedJobs;
  final List<Unit> units;

  Course({
    required this.id,
    required this.title,
    required this.duration,
    required this.badge,
    required this.matchedJobs,
    required this.units,
  });
}

class Unit {
  final String title;
  final String subtitle;
  final String pdfUrl;
  final String videoUrl; // Firebase Storage download URL (was youtubeUrl)

  Unit({
    required this.title,
    required this.subtitle,
    required this.pdfUrl,
    required this.videoUrl,
  });
}
