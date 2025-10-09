import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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
        .set({'completed': true, 'completedAt': Timestamp.now()});
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unit marked as completed!'),
        backgroundColor: Colors.green,
      ),
    );
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
    if (unitIds.isEmpty) return false;

    int completed = 0;
    for (String id in unitIds) {
      if (await _isUnitCompleted(id)) completed++;
    }
    return completed == unitIds.length;
  }

  Future<void> _viewPdf(String pdfBase64, String fileName) async {
    try {
      // Show loading dialog
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

      // Convert base64 to bytes
      final pdfBytes = base64.decode(pdfBase64);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Write PDF to temporary file
      await file.writeAsBytes(pdfBytes);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Open the PDF file
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

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
      // Show loading dialog
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

      // Convert base64 to bytes
      final pdfBytes = base64.decode(pdfBase64);

      // Get downloads directory (or documents directory as fallback)
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

      // Write PDF to file
      await file.writeAsBytes(pdfBytes);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF downloaded to: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

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
            ListTile(
              leading: const Icon(Icons.share, color: Colors.orange),
              title: const Text('Share PDF'),
              subtitle: const Text('Share with other apps'),
              onTap: () {
                Navigator.pop(context);
                _sharePdf(pdfBase64, fileName);
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

  Future<void> _sharePdf(String pdfBase64, String fileName) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing PDF for sharing...'),
            ],
          ),
        ),
      );

      // Convert base64 to bytes
      final pdfBytes = base64.decode(pdfBase64);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Write PDF to temporary file
      await file.writeAsBytes(pdfBytes);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF ready for sharing (install share_plus package for full functionality)',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing PDF for sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _launchYouTubeVideo(String videoUrl) async {
    final youtubeId = YoutubePlayer.convertUrlToId(videoUrl);
    if (youtubeId != null) {
      // Already handled by YoutubePlayer widget
      return;
    }

    if (await canLaunchUrl(Uri.parse(videoUrl))) {
      await launchUrl(
        Uri.parse(videoUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not open video"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCompletionBadge(bool isCompleted) {
    if (!isCompleted) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🎉 Course Completed!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepOrange,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "You've successfully completed all units in this course",
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(
    Map<String, dynamic> unit,
    String unitId,
    bool isCompleted,
  ) {
    final unitTitle = unit['title'] ?? 'Untitled Unit';
    final description = unit['description'] ?? '';
    final youtubeUrl = unit['youtubeUrl'] ?? '';
    final hasPdf = unit['hasPdf'] ?? false;
    final pdfFileName = unit['pdfFileName'] ?? '';
    final pdfBase64 = unit['pdfBase64'] ?? '';
    final fileSize = unit['pdfFileSize'] ?? 0;

    final youtubeId = YoutubePlayer.convertUrlToId(youtubeUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and completion status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    unitTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 20),

            // YouTube Video
            if (youtubeId != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Video Lesson',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: YoutubePlayer(
                        controller: YoutubePlayerController(
                          initialVideoId: youtubeId,
                          flags: const YoutubePlayerFlags(
                            autoPlay: false,
                            mute: false,
                            disableDragSeek: false,
                            loop: false,
                            isLive: false,
                            forceHD: false,
                            enableCaption: true,
                          ),
                        ),
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: Colors.blueAccent,
                        progressColors: const ProgressBarColors(
                          playedColor: Colors.blueAccent,
                          handleColor: Colors.blueAccent,
                        ),
                        onReady: () {
                          // You can add any onReady logic here
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _launchYouTubeVideo(youtubeUrl),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open in YouTube'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // PDF Section
            if (hasPdf && pdfBase64.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Study Materials',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red.shade600,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pdfFileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(fileSize / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showPdfOptions(pdfBase64, pdfFileName),
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.blue.shade600,
                          ),
                          tooltip: 'PDF Options',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // Completion Button
            if (!isCompleted)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _markUnitCompleted(unitId),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _courseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading course...'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Course Not Found')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Course not found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final courseData = snapshot.data!.data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'Course';
        final description = courseData['description'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.blueAccent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
              ),
            ),
            child: Column(
              children: [
                // Course Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),

                // Course Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _unitsRef.orderBy('createdAt').snapshots(),
                      builder: (context, unitSnapshot) {
                        if (unitSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final units = unitSnapshot.data?.docs ?? [];
                        if (units.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.library_books,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No units available yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Check back later for course content',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return FutureBuilder<bool>(
                          future: _isCourseCompleted(
                            units.map((e) => e.id).toList(),
                          ),
                          builder: (context, badgeSnapshot) {
                            return Column(
                              children: [
                                _buildCompletionBadge(
                                  badgeSnapshot.data ?? false,
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: units.length,
                                    itemBuilder: (context, index) {
                                      final unit =
                                          units[index].data()
                                              as Map<String, dynamic>;
                                      final unitId = units[index].id;

                                      return FutureBuilder<bool>(
                                        future: _isUnitCompleted(unitId),
                                        builder: (context, completionSnapshot) {
                                          final isCompleted =
                                              completionSnapshot.data ?? false;
                                          return _buildUnitCard(
                                            unit,
                                            unitId,
                                            isCompleted,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
