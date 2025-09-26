import 'package:fixem/Models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class UnitDetailPage extends StatelessWidget {
  final Unit unit;
  const UnitDetailPage({super.key, required this.unit});

  void _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String videoId = YoutubePlayer.convertUrlToId(unit.youtubeUrl)!;
    final YoutubePlayerController _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: false),
    );

    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            YoutubePlayer(controller: _controller),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openPdf(unit.pdfUrl),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download/View PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
