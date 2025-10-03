import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CourseOverviewPage extends StatefulWidget {
  final String courseId;

  const CourseOverviewPage({super.key, required this.courseId});

  @override
  State<CourseOverviewPage> createState() => _CourseOverviewPageState();
}

class _CourseOverviewPageState extends State<CourseOverviewPage> {
  late Future<DocumentSnapshot> _courseFuture;
  late CollectionReference _unitsRef;
  String userId = 'sampleUser123'; // Replace with actual auth user UID

  @override
  void initState() {
    super.initState();
    _courseFuture = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .get();
    _unitsRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('units');
  }

  Future<void> _markUnitCompleted(String unitId) async {
    await FirebaseFirestore.instance
        .collection('user_progress')
        .doc(userId)
        .collection('completed_units')
        .doc(unitId)
        .set({'completed': true});
    setState(() {});
  }

  Future<bool> _isUnitCompleted(String unitId) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_progress')
        .doc(userId)
        .collection('completed_units')
        .doc(unitId)
        .get();
    return doc.exists;
  }

  Future<bool> _isCourseCompleted(List<String> unitIds) async {
    int completed = 0;
    for (String id in unitIds) {
      if (await _isUnitCompleted(id)) completed++;
    }
    return completed == unitIds.length;
  }

  void _launchPdf(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open PDF")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _courseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Course not found')));
        }

        final courseData = snapshot.data!.data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'Course';
        final description = courseData['description'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.lightBlueAccent,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                const Text("Course Units",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _unitsRef.snapshots(),
                    builder: (context, unitSnapshot) {
                      if (unitSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final units = unitSnapshot.data!.docs;
                      if (units.isEmpty) {
                        return const Text("No units added to this course.");
                      }

                      return FutureBuilder<bool>(
                        future: _isCourseCompleted(units.map((e) => e.id).toList()),
                        builder: (context, badgeSnapshot) {
                          return Column(
                            children: [
                              if (badgeSnapshot.data == true)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.verified, color: Colors.orange),
                                      SizedBox(width: 10),
                                      Text("🎉 Badge Unlocked!",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: units.length,
                                  itemBuilder: (context, index) {
                                    final unit = units[index].data()
                                        as Map<String, dynamic>;
                                    final unitId = units[index].id;
                                    final unitTitle = unit['title'] ?? 'Unit';
                                    final pdfUrl = unit['pdfUrl'] ?? '';
                                    final videoUrl = unit['videoUrl'] ?? '';

                                    final youtubeId =
                                        YoutubePlayer.convertUrlToId(videoUrl);

                                    return FutureBuilder<bool>(
                                      future: _isUnitCompleted(unitId),
                                      builder: (context, snapshot) {
                                        final isCompleted = snapshot.data ?? false;
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(unitTitle,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                    if (isCompleted)
                                                      const Icon(Icons.check_circle,
                                                          color: Colors.green),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                if (youtubeId != null)
                                                  YoutubePlayer(
                                                    controller: YoutubePlayerController(
                                                      initialVideoId: youtubeId,
                                                      flags:
                                                          const YoutubePlayerFlags(
                                                              autoPlay: false,
                                                              mute: false),
                                                    ),
                                                    showVideoProgressIndicator: true,
                                                  ),
                                                const SizedBox(height: 10),
                                                ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _launchPdf(pdfUrl),
                                                  icon: const Icon(Icons.download),
                                                  label:
                                                      const Text('Download PDF'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.lightBlueAccent,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                if (!isCompleted)
                                                  ElevatedButton(
                                                    onPressed: () => _markUnitCompleted(
                                                        unitId),
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.green),
                                                    child: const Text(
                                                        "Mark as Completed"),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
