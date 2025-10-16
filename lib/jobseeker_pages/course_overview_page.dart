import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

class CourseOverviewPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseOverviewPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseOverviewPage> createState() => _CourseOverviewPageState();
}

class _CourseOverviewPageState extends State<CourseOverviewPage> {
  late CollectionReference _unitsRef;
  String? userId;
  
  // Track video completion status for each unit
  Map<String, bool> videoCompletionStatus = {};
  Map<String, YoutubePlayerController> videoControllers = {};

  @override
  void initState() {
    super.initState();
    _unitsRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('units');
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _markUnitCompleted(String unitId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Check if video was watched completely
      if (videoCompletionStatus[unitId] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please watch the full video before marking as complete'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Mark unit as completed
      await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(userId)
          .collection('completed_units')
          .doc(unitId)
          .set({
            'completed': true,
            'completedAt': Timestamp.now(),
            'courseId': widget.courseId,
            'unitId': unitId,
          });

      // Check if all units in the course are completed
      await _checkCourseCompletion();

      setState(() {});
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Unit marked as completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkCourseCompletion() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get all units for this course
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('units')
          .get();

      // Get completed units for this course
      final completedUnitsSnapshot = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(userId)
          .collection('completed_units')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      final totalUnits = unitsSnapshot.docs.length;
      final completedUnits = completedUnitsSnapshot.docs.length;

      // If all units are completed, award the badge
      if (totalUnits > 0 && completedUnits >= totalUnits) {
        await _awardCourseBadge();
      }
    } catch (e) {
      print('Error checking course completion: $e');
    }
  }

  Future<void> _awardCourseBadge() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Check if badge already awarded
      final existingBadge = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(userId)
          .collection('badges')
          .doc(widget.courseId)
          .get();

      if (existingBadge.exists) return;

      // Get course details to create badge
      final courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get();

      if (courseDoc.exists) {
        final courseData = courseDoc.data()!;
        final badgeTitle = courseData['badge'] ?? 'Course Completion Badge';
        final courseTitle = courseData['title'] ?? 'Unknown Course';

        // Award the badge
        await FirebaseFirestore.instance
            .collection('user_badges')
            .doc(userId)
            .collection('badges')
            .doc(widget.courseId)
            .set({
              'badgeTitle': badgeTitle,
              'courseTitle': courseTitle,
              'courseId': widget.courseId,
              'awardedAt': Timestamp.now(),
              'description': courseData['description'] ?? '',
              'duration': courseData['duration'] ?? '',
              'matchedJobs': courseData['matchedJobs'] ?? '',
            });

        // Update badges count in user profile
        await _updateUserBadgesCount();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Congratulations! You earned the $badgeTitle badge!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error awarding badge: $e');
    }
  }

  Future<void> _updateUserBadgesCount() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final badgesSnapshot = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(userId)
          .collection('badges')
          .get();

      final badgesCount = badgesSnapshot.docs.length;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'badgesCount': badgesCount,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating badges count: $e');
    }
  }

  Future<bool> _isUnitCompleted(String unitId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(userId)
          .collection('completed_units')
          .doc(unitId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> _viewPdf(String pdfBase64, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing PDF...'),
            ],
          ),
        ),
      );

      final pdfBytes = base64.decode(pdfBase64);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) Navigator.of(context).pop();

      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadPdf(String pdfBase64, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Downloading PDF...'),
            ],
          ),
        ),
      );

      final pdfBytes = base64.decode(pdfBase64);

      Directory? downloadsDir;
      try {
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          downloadsDir = await getDownloadsDirectory();
        }
      } catch (e) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${downloadsDir?.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF downloaded to: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPdfOptions(String pdfBase64, String fileName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PDF Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View PDF'),
              subtitle: const Text('Open PDF in viewer'),
              onTap: () {
                Navigator.pop(context);
                _viewPdf(pdfBase64, fileName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Download PDF'),
              subtitle: const Text('Save to device storage'),
              onTap: () {
                Navigator.pop(context);
                _downloadPdf(pdfBase64, fileName);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _launchYouTubeVideo(String videoUrl) async {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No YouTube video available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (await canLaunchUrl(Uri.parse(videoUrl))) {
        await launchUrl(
          Uri.parse(videoUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open video"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening video: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUnitItem(DocumentSnapshot unitDoc, int index) {
    final unit = unitDoc.data() as Map<String, dynamic>;
    final unitId = unitDoc.id;
    final unitTitle = unit['title'] ?? 'Untitled Unit';
    final unitDescription = unit['description'] ?? '';
    final youtubeUrl = unit['youtubeUrl'] ?? '';
    final hasPdf = unit['hasPdf'] ?? false;
    final pdfFileName = unit['pdfFileName'] ?? '';
    final pdfBase64 = unit['pdfBase64'] ?? '';
    final fileSize = unit['pdfFileSize'] ?? 0;
    final hasYouTube = youtubeUrl.isNotEmpty;

    // Initialize video completion status
    if (!videoCompletionStatus.containsKey(unitId)) {
      videoCompletionStatus[unitId] = false;
    }

    // YouTube Player Controller with seek disabled
    YoutubePlayerController? controller;
    if (hasYouTube) {
      final videoId = YoutubePlayer.convertUrlToId(youtubeUrl);
      if (videoId != null) {
        // Check if controller already exists for this unit
        if (!videoControllers.containsKey(unitId)) {
          controller = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              enableCaption: true,
              disableDragSeek: true, // ✅ Disable seeking/skipping
              hideControls: false,
              controlsVisibleAtStart: true,
            ),
          );
          videoControllers[unitId] = controller;
        } else {
          controller = videoControllers[unitId];
        }
      }
    }

    return FutureBuilder<bool>(
      future: _isUnitCompleted(unitId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;
        final canComplete = videoCompletionStatus[unitId] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unit Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Number
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Unit Title and Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unitTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? Colors.green
                                  : Colors.black87,
                            ),
                          ),
                          if (unitDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              unitDescription,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ✅ Embedded YouTube Video Section - ALWAYS VISIBLE
                if (hasYouTube && controller != null) ...[
                  const Text(
                    "Video Lesson",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // YouTube Player with seek disabled
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: YoutubePlayer(
                      controller: controller,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.redAccent,
                      onEnded: (metaData) {
                        // Video has ended - mark as watched
                        setState(() {
                          videoCompletionStatus[unitId] = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Video completion status indicator (only show if not completed)
                  if (!isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: canComplete ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: canComplete ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canComplete ? Icons.check_circle : Icons.info_outline,
                            size: 18,
                            color: canComplete ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              canComplete
                                  ? '✓ Video watched completely'
                                  : '⚠️ Please watch the full video to mark as complete',
                              style: TextStyle(
                                fontSize: 13,
                                color: canComplete ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Open in YouTube link
                  GestureDetector(
                    onTap: () => _launchYouTubeVideo(youtubeUrl),
                    child: const Row(
                      children: [
                        Icon(Icons.open_in_new, color: Colors.blue, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Open in YouTube",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // PDF Section - ALWAYS AVAILABLE
                if (hasPdf && pdfFileName.isNotEmpty) ...[
                  const Text(
                    "Study Materials",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        // PDF Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // PDF Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pdfFileName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(fileSize / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // View PDF button with options
                        IconButton(
                          onPressed: () =>
                              _showPdfOptions(pdfBase64, pdfFileName),
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.blue,
                            size: 24,
                          ),
                          tooltip: 'PDF Options',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Complete Button - Only enabled after video is watched
                if (!isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canComplete
                          ? () => _markUnitCompleted(unitId)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canComplete ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                      ),
                      child: Text(
                        canComplete
                            ? 'Mark as Completed'
                            : 'Watch Video to Complete',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Completed Badge
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Unit Completed',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "COURSE OVERVIEW",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _unitsRef.orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading course content...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No units available yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final units = snapshot.data!.docs;

          return Column(
            children: [
              // Course Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.courseTitle.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Units List
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Course Units",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView.builder(
                          itemCount: units.length,
                          itemBuilder: (context, index) {
                            return _buildUnitItem(units[index], index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all YouTube controllers
    for (var controller in videoControllers.values) {
      controller.dispose();
    }
    videoControllers.clear();
    super.dispose();
  }
}