import 'package:chewie/chewie.dart';
import 'package:fixem/Models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class UnitDetailPage extends StatefulWidget {
  final Unit unit;
  const UnitDetailPage({super.key, required this.unit});

  @override
  State<UnitDetailPage> createState() => _UnitDetailPageState();
}

class _UnitDetailPageState extends State<UnitDetailPage> {
  VideoPlayerController? _vpController;
  ChewieController? _chewieController;
  bool _isLoadingVideo = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.unit.videoUrl.isNotEmpty) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isLoadingVideo = true;
      _videoError = null;
    });

    try {
      final vpController = VideoPlayerController.networkUrl(
        Uri.parse(widget.unit.videoUrl),
      );
      _vpController = vpController;
      await vpController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: vpController,
        autoPlay: false,
        looping: false,
        draggableProgressBar: false, // 🔒 no seeking/skipping
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.blueAccent.withValues(alpha: 0.4),
        ),
      );
    } catch (e) {
      _videoError = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingVideo = false);
    }
  }

  Future<void> _openPdf(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.unit.videoUrl.isNotEmpty;
    final hasPdf = widget.unit.pdfUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(widget.unit.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Video Player ─────────────────────────────────────────
            if (hasVideo) ...[
              const Text(
                'Video Lesson',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _buildVideoPlayer(),
              const SizedBox(height: 20),
            ],

            // ── PDF Button ───────────────────────────────────────────
            if (hasPdf)
              ElevatedButton.icon(
                onPressed: () => _openPdf(widget.unit.pdfUrl),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download/View PDF'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoadingVideo) {
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
              Text('Loading video…', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_videoError != null) {
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
              Text(
                _videoError!,
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

    if (_chewieController == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: _vpController?.value.aspectRatio ?? 16 / 9,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _vpController?.dispose();
    super.dispose();
  }
}
