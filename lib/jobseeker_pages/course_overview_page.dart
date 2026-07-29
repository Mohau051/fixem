import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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

  /// Whether the video for each unit has been fully watched
  final Map<String, bool> _videoCompleted = {};

  /// Native video controllers keyed by unitId
  final Map<String, VideoPlayerController> _vpControllers = {};

  /// Chewie controllers keyed by unitId
  final Map<String, ChewieController> _chewieControllers = {};

  /// Whether the player for a unit is still initialising
  final Map<String, bool> _playerLoading = {};

  /// Whether a player had an error initialising
  final Map<String, String?> _playerError = {};

  @override
  void initState() {
    super.initState();
    _unitsRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('units');
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

  // ── Video player lifecycle ───────────────────────────────────────────────

  Future<void> _initVideoPlayer(String unitId, String videoUrl) async {
    if (_vpControllers.containsKey(unitId)) return; // already initialised

    setState(() => _playerLoading[unitId] = true);

    try {
      final vpController =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _vpControllers[unitId] = vpController;
      await vpController.initialize();

      // Listen for video completion
      vpController.addListener(() {
        if (!mounted) return;
        final pos = vpController.value.position;
        final dur = vpController.value.duration;
        // Mark complete when within 1 second of end
        if (dur.inSeconds > 0 &&
            pos.inSeconds >= dur.inSeconds - 1 &&
            _videoCompleted[unitId] != true) {
          setState(() => _videoCompleted[unitId] = true);
        }
      });

      final chewieController = ChewieController(
        videoPlayerController: vpController,
        autoPlay: false,
        looping: false,
        draggableProgressBar: false, // 🔒 prevent seeking/skipping
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.blueAccent.withValues(alpha: 0.4),
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (ctx, msg) => Center(
          child: Text(
            'Error playing video: $msg',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );

      _chewieControllers[unitId] = chewieController;
    } catch (e) {
      _playerError[unitId] = e.toString();
    } finally {
      if (mounted) setState(() => _playerLoading[unitId] = false);
    }
  }

  // ── Unit completion ──────────────────────────────────────────────────────

  Future<void> _markUnitCompleted(String unitId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (_videoCompleted[unitId] != true) {
        _showSnack(
          '⚠️ Please watch the full video before marking as complete',
          color: Colors.orange,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(uid)
          .collection('completed_units')
          .doc(unitId)
          .set({
        'completed': true,
        'completedAt': Timestamp.now(),
        'courseId': widget.courseId,
        'unitId': unitId,
      });

      await _checkCourseCompletion();
      if (mounted) setState(() {});
      _showSnack('✅ Unit marked as completed!', color: Colors.green);
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
    }
  }

  Future<void> _checkCourseCompletion() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final unitsSnap = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('units')
          .get();

      final completedSnap = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(uid)
          .collection('completed_units')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      if (unitsSnap.docs.isNotEmpty &&
          completedSnap.docs.length >= unitsSnap.docs.length) {
        await _awardCourseBadge();
      }
    } catch (e) {
      debugPrint('Error checking course completion: $e');
    }
  }

  Future<void> _awardCourseBadge() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final existing = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(uid)
          .collection('badges')
          .doc(widget.courseId)
          .get();
      if (existing.exists) return;

      final courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get();

      if (courseDoc.exists) {
        final data = courseDoc.data()!;
        await FirebaseFirestore.instance
            .collection('user_badges')
            .doc(uid)
            .collection('badges')
            .doc(widget.courseId)
            .set({
          'badgeTitle': data['badge'] ?? 'Course Completion Badge',
          'courseTitle': data['title'] ?? 'Unknown Course',
          'courseId': widget.courseId,
          'awardedAt': Timestamp.now(),
          'description': data['description'] ?? '',
          'duration': data['duration'] ?? '',
          'matchedJobs': data['matchedJobs'] ?? '',
        });

        await _updateUserBadgesCount();
        _showSnack(
          '🎉 Congratulations! You earned the ${data['badge'] ?? 'Course Completion'} badge!',
          color: Colors.green,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      debugPrint('Error awarding badge: $e');
    }
  }

  Future<void> _updateUserBadgesCount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(uid)
          .collection('badges')
          .get();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'badgesCount': snap.docs.length,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating badge count: $e');
    }
  }

  Future<bool> _isUnitCompleted(String unitId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(uid)
          .collection('completed_units')
          .doc(unitId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── PDF helpers ──────────────────────────────────────────────────────────

  Future<void> _viewPdf(String pdfBase64, String fileName) async {
    try {
      _showLoadingDialog('Preparing PDF…');
      final bytes = base64.decode(pdfBase64);

      // Save to app documents directory — always accessible, no permission needed
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) Navigator.of(context).pop();

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _showSnack(
          'No PDF viewer found. Try installing a PDF app.',
          color: Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        _showSnack('Error opening PDF: $e', color: Colors.red);
      }
    }
  }

  Future<void> _downloadPdf(String pdfBase64, String fileName) async {
    try {
      _showLoadingDialog('Saving PDF…');
      final bytes = base64.decode(pdfBase64);

      // Use app documents directory — works on all Android versions without permissions
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) Navigator.of(context).pop();

      // Open it immediately so the user can also share/save from their PDF viewer
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _showSnack(
          'PDF saved to: ${file.path}',
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        _showSnack('Error saving PDF: $e', color: Colors.red);
      }
    }
  }

  void _showPdfOptions(String pdfBase64, String fileName) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
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
                Navigator.pop(ctx);
                _viewPdf(pdfBase64, fileName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Download PDF'),
              subtitle: const Text('Save to device storage'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadPdf(pdfBase64, fileName);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared UI helpers ────────────────────────────────────────────────────

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnack(
    String message, {
    Color? color,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
      ),
    );
  }

  // ── Unit Item ────────────────────────────────────────────────────────────

  Widget _buildUnitItem(DocumentSnapshot unitDoc, int index) {
    final unit = unitDoc.data() as Map<String, dynamic>;
    final unitId = unitDoc.id;
    final unitTitle = unit['title'] ?? 'Untitled Unit';
    final unitDescription = unit['description'] ?? '';

    // Video
    final hasVideo = (unit['hasVideo'] ?? false) as bool;
    final videoUrl = (unit['videoUrl'] ?? '') as String;

    // PDF
    final hasPdf = (unit['hasPdf'] ?? false) as bool;
    final pdfFileName = (unit['pdfFileName'] ?? '') as String;
    final pdfBase64 = (unit['pdfBase64'] ?? '') as String;
    final fileSize = (unit['pdfFileSize'] ?? 0) as int;

    // Initialise video map entries
    _videoCompleted.putIfAbsent(unitId, () => false);

    // Kick off player init if needed (only once per unit)
    if (hasVideo && videoUrl.isNotEmpty && !_vpControllers.containsKey(unitId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initVideoPlayer(unitId, videoUrl);
      });
    }

    return FutureBuilder<bool>(
      future: _isUnitCompleted(unitId),
      builder: (ctx, snapshot) {
        final isCompleted = snapshot.data ?? false;
        final canComplete = _videoCompleted[unitId] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
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
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green
                            : Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
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

                // ── In-house Video Player ──────────────────────────────
                if (hasVideo && videoUrl.isNotEmpty) ...[
                  const Text(
                    'Video Lesson',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildVideoPlayer(unitId),
                  const SizedBox(height: 10),

                  // Status pill (only while not yet completed)
                  if (!isCompleted) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: canComplete
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: canComplete
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canComplete
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 18,
                            color: canComplete
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              canComplete
                                  ? '✓ Video watched — you can now mark this unit as complete'
                                  : '⚠️ Watch the full video to unlock completion',
                              style: TextStyle(
                                fontSize: 13,
                                color: canComplete
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 10),
                ],

                // ── PDF Section ────────────────────────────────────────
                if (hasPdf && pdfFileName.isNotEmpty) ...[
                  const Text(
                    'Study Materials',
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

                // ── Complete / Completed button ─────────────────────────
                if (!isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (canComplete || !hasVideo)
                          ? () => _markUnitCompleted(unitId)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (canComplete || !hasVideo)
                                ? Colors.green
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor:
                            Colors.grey.shade300,
                        disabledForegroundColor:
                            Colors.grey.shade600,
                      ),
                      child: Text(
                        (canComplete || !hasVideo)
                            ? 'Mark as Completed'
                            : 'Watch Video to Complete',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

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
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
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

  // ── In-house video player widget ─────────────────────────────────────────

  Widget _buildVideoPlayer(String unitId) {
    final isLoading = _playerLoading[unitId] ?? false;
    final error = _playerError[unitId];
    final chewie = _chewieControllers[unitId];

    if (isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                'Loading video…',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Could not load video',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                error,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    if (chewie == null) {
      // Still awaiting first frame callback to init
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: _vpControllers[unitId]?.value.aspectRatio ?? 16 / 9,
        child: Chewie(controller: chewie),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'COURSE OVERVIEW',
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
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading course content…'),
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
                child: Text(
                  widget.courseTitle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
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
                        'Course Units',
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
                          itemBuilder: (ctx, index) =>
                              _buildUnitItem(units[index], index),
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
    for (final c in _chewieControllers.values) {
      c.dispose();
    }
    for (final c in _vpControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}