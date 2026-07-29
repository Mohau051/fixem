import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:path_provider/path_provider.dart';

class CreateUnitPage extends StatefulWidget {
  const CreateUnitPage({super.key});

  @override
  State<CreateUnitPage> createState() => _CreateUnitPageState();
}

class _CreateUnitPageState extends State<CreateUnitPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isPickingPdf = false;
  bool _isPickingVideo = false;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0.0;
  String _uploadStatus = '';

  String? _selectedCourseId;

  // PDF state
  String? _pdfFileName;
  Uint8List? _pdfBytes;

  // Video state — store bytes (works on all platforms, avoids content:// URI)
  String? _videoFileName;
  Uint8List? _videoBytes;
  int _videoSizeBytes = 0;

  // ── Firestore helpers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('courses').get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, 'title': doc['title']})
          .toList();
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      return [];
    }
  }

  Future<int> _getNextOrderNumber() async {
    if (_selectedCourseId == null) return 1;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId!)
          .collection('units')
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return (snapshot.docs.first['order'] ?? 0) + 1;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickPDF() async {
    if (_isPickingPdf) return;
    setState(() => _isPickingPdf = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.bytes == null) {
          _showSnack('Could not read PDF file content');
          return;
        }
        if (file.bytes!.length > 10 * 1024 * 1024) {
          _showSnack('PDF exceeds 10 MB limit', isError: true);
          return;
        }
        setState(() {
          _pdfFileName = file.name;
          _pdfBytes = file.bytes;
        });
        _showSnack('PDF "${file.name}" selected!');
      }
    } catch (e) {
      _showSnack('Error selecting PDF: $e', isError: true);
    } finally {
      setState(() => _isPickingPdf = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_isPickingVideo) return;
    setState(() => _isPickingVideo = true);

    try {
      // withData:true loads bytes in memory — avoids Android content:// URI issues
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // Validate extension
        final validExtensions = ['.mp4', '.mov', '.avi', '.mkv'];
        if (!validExtensions.any((ext) => file.name.toLowerCase().endsWith(ext))) {
          _showSnack('Please select MP4, MOV, AVI or MKV', isError: true);
          return;
        }

        // Bytes must be present
        if (file.bytes == null || file.bytes!.isEmpty) {
          _showSnack('Could not read video bytes. Try a smaller file.', isError: true);
          return;
        }

        // 200 MB cap
        if (file.size > 200 * 1024 * 1024) {
          _showSnack('Video exceeds 200 MB limit', isError: true);
          return;
        }

        setState(() {
          _videoFileName = file.name;
          _videoSizeBytes = file.size;
          _videoBytes = file.bytes;
        });

        _showSnack('Video "${file.name}" ready (${_formatBytes(file.size)})');
      }
    } catch (e) {
      _showSnack('Error selecting video: $e', isError: true);
    } finally {
      setState(() => _isPickingVideo = false);
    }
  }

  // ── Firebase Storage upload ───────────────────────────────────────────────

  Future<String?> _uploadVideoToStorage(String courseId) async {
    if (_videoFileName == null || _videoBytes == null) return null;

    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
      _uploadStatus = 'Preparing upload…';
    });

    File? tempFile;
    try {
      // Write bytes to a real temp file first.
      // This avoids Android content:// URI and RAM exhaustion on large files.
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/$_videoFileName');
      await tempFile.writeAsBytes(_videoBytes!, flush: true);

      if (!await tempFile.exists()) {
        _showSnack('Failed to create temp file for upload', isError: true);
        return null;
      }

      // Upload to Firebase Storage under the correct bucket
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://fix-em-6b9bd.firebasestorage.app',
      );
      final storageRef = storage
          .ref()
          .child('unit_videos')
          .child(courseId)
          .child(_videoFileName!);

      if (mounted) setState(() => _uploadStatus = 'Uploading…');

      final uploadTask = storageRef.putFile(
        tempFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Track progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted && snapshot.totalBytes > 0) {
          setState(() {
            _videoUploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadStatus =
                'Uploading ${(_videoUploadProgress * 100).toStringAsFixed(0)}%…';
          });
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (mounted) setState(() => _uploadStatus = 'Upload complete ✓');
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      _showSnack('Video upload failed: $e', isError: true);
      return null;
    } finally {
      // Clean up temp file
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => _isUploadingVideo = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) return;

    setState(() => _isLoading = true);

    try {
      final orderNumber = await _getNextOrderNumber();

      // Upload video first
      String? videoUrl;
      if (_videoFileName != null) {
        videoUrl = await _uploadVideoToStorage(_selectedCourseId!);
        if (videoUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Encode PDF to base64
      String pdfBase64 = '';
      if (_pdfBytes != null && _pdfFileName != null) {
        pdfBase64 = base64.encode(_pdfBytes!);
      }

      final unitData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'order': orderNumber,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        // Video
        'videoUrl': videoUrl ?? '',
        'videoFileName': _videoFileName ?? '',
        'hasVideo': videoUrl != null,
        // PDF
        'pdfFileName': _pdfFileName ?? '',
        'pdfFileSize': _pdfBytes?.length ?? 0,
        'pdfBase64': pdfBase64,
        'hasPdf': pdfBase64.isNotEmpty,
      };

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('units')
          .add(unitData);

      _showSnack('✅ Unit created successfully!', isSuccess: true);
      _clearForm();
    } catch (e) {
      _showSnack('Failed to save unit: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Form helpers ──────────────────────────────────────────────────────────

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _pdfFileName = null;
      _pdfBytes = null;
      _videoFileName = null;
      _videoBytes = null;
      _videoSizeBytes = 0;
      _selectedCourseId = null;
      _videoUploadProgress = 0.0;
      _uploadStatus = '';
    });
  }

  void _removePdf() => setState(() {
        _pdfFileName = null;
        _pdfBytes = null;
      });

  void _removeVideo() => setState(() {
        _videoFileName = null;
        _videoBytes = null;
        _videoSizeBytes = 0;
        _videoUploadProgress = 0.0;
        _uploadStatus = '';
      });

  void _showSnack(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Unit'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCourses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading courses: ${snapshot.error}'),
            );
          }

          final courses = snapshot.data ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Course Selection
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Course *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    value: _selectedCourseId,
                    items: courses
                        .map<DropdownMenuItem<String>>(
                          (c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(c['title'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                    validator: (v) =>
                        v == null ? 'Please select a course' : null,
                  ),

                  const SizedBox(height: 20),

                  // Unit Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Title *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => v!.isEmpty ? 'Enter unit title' : null,
                  ),

                  const SizedBox(height: 16),

                  // Unit Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Description *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? 'Enter description' : null,
                  ),

                  const SizedBox(height: 20),

                  // Video Upload Card
                  _buildVideoUploadCard(),

                  const SizedBox(height: 16),

                  // PDF Upload Card
                  _buildPdfUploadCard(),

                  const SizedBox(height: 30),

                  // Save Button / Progress
                  if (_isLoading || _isUploadingVideo)
                    Column(
                      children: [
                        if (_isUploadingVideo) ...[
                          Text(
                            _uploadStatus,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _videoUploadProgress > 0
                                  ? _videoUploadProgress
                                  : null, // null = indeterminate during prep
                              minHeight: 10,
                              backgroundColor: Colors.grey[200],
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Center(child: CircularProgressIndicator()),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _saveUnit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'SAVE UNIT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Video Upload Card ─────────────────────────────────────────────────────

  Widget _buildVideoUploadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam,
                      color: Colors.blueAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Lesson (Optional)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'MP4, MOV, AVI or MKV · Max 200 MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isPickingVideo)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading video file…'),
                  ],
                ),
              )
            else if (_videoFileName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.movie, color: Colors.blueAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _videoFileName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_videoSizeBytes > 0)
                            Text(
                              _formatBytes(_videoSizeBytes),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _removeVideo,
                      tooltip: 'Remove video',
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select Video File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.08),
                  foregroundColor: Colors.blueAccent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── PDF Upload Card ───────────────────────────────────────────────────────

  Widget _buildPdfUploadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Study Material (Optional)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Stored in Firestore · Max 10 MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isPickingPdf)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Selecting PDF…'),
                  ],
                ),
              )
            else if (_pdfFileName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pdfFileName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_pdfBytes != null)
                            Text(
                              _formatBytes(_pdfBytes!.length),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _removePdf,
                      tooltip: 'Remove PDF',
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _pickPDF,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.08),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
