import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;

class CreateUnitPage extends StatefulWidget {
  const CreateUnitPage({super.key});

  @override
  State<CreateUnitPage> createState() => _CreateUnitPageState();
}

class _CreateUnitPageState extends State<CreateUnitPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();

  bool _isLoading = false;
  bool _isPickingPdf = false;
  String? _selectedCourseId;
  String? _pdfFileName;
  Uint8List? _pdfBytes;
  bool _isMuted = false;
  bool _videoWatchedCompletely = false; // ✅ New

  

  // Load all courses from Firestore for dropdown
  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, 'title': doc['title']})
          .toList();
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  // Get the next order number for the selected course
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
        final lastOrder = snapshot.docs.first['order'] ?? 0;
        return lastOrder + 1;
      }
      return 1;
    } catch (e) {
      print('Error getting order number: $e');
      return 1;
    }
  }

  // Pick PDF from device
  Future<void> _pickPDF() async {
    if (_isPickingPdf) return;

    setState(() => _isPickingPdf = true);

    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
          allowCompression: true,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: ${e.toString()}')),
        );
        return;
      }

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;

        if (!platformFile.name.toLowerCase().endsWith('.pdf')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a PDF file (.pdf extension)'),
            ),
          );
          return;
        }

        if (platformFile.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read PDF file content')),
          );
          return;
        }

        setState(() {
          _pdfFileName = platformFile.name;
          _pdfBytes = platformFile.bytes;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF "${platformFile.name}" selected! Click SAVE UNIT to save.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting PDF: ${e.toString()}')),
      );
    } finally {
      setState(() => _isPickingPdf = false);
    }
  }

  // Convert bytes to base64 string
  String _bytesToBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  // Save unit to Firestore
  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get the next order number
      final orderNumber = await _getNextOrderNumber();

      Map<String, dynamic> pdfData = {};
      String? pdfBase64;

      // Handle PDF upload
      if (_pdfBytes != null && _pdfFileName != null) {
        // File size limit check (10MB)
        if (_pdfBytes!.length > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("File size exceeds 10MB limit"),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        pdfBase64 = _bytesToBase64(_pdfBytes!);
      }

      // Prepare unit data WITH ORDER FIELD
      Map<String, dynamic> unitData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'youtubeUrl': _youtubeUrlController.text.trim(),
        'order': orderNumber, // THIS IS THE CRITICAL FIELD THAT WAS MISSING
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      // Handle PDF data
      if (pdfBase64 != null) {
        unitData.addAll({
          'pdfFileName': _pdfFileName,
          'pdfFileSize': _pdfBytes!.length,
          'pdfBase64': pdfBase64,
          'hasPdf': true,
        });
      } else {
        unitData.addAll({
          'pdfFileName': '',
          'pdfFileSize': 0,
          'pdfBase64': '',
          'hasPdf': false,
        });
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('units')
          .add(unitData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unit created successfully!'),
          duration: Duration(seconds: 3),
        ),
      );

      // Clear form after successful save
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save unit: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Clear form fields
  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _youtubeUrlController.clear();
    setState(() {
      _pdfFileName = null;
      _pdfBytes = null;
      _selectedCourseId = null;
    });
  }

  // Remove selected PDF
  void _removePdf() {
    setState(() {
      _pdfFileName = null;
      _pdfBytes = null;
    });
  }

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
                          (course) => DropdownMenuItem<String>(
                            value: course['id'] as String,
                            child: Text(course['title'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                    validator: (value) =>
                        value == null ? 'Please select a course' : null,
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
                    validator: (value) =>
                        value!.isEmpty ? 'Enter unit title' : null,
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
                    validator: (value) =>
                        value!.isEmpty ? 'Enter description' : null,
                  ),

                  const SizedBox(height: 16),

                  // YouTube URL
                  TextFormField(
                    controller: _youtubeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube Video URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.video_library),
                    ),
                    // Made optional since your screenshot shows PDF-focused content
                  ),

                  const SizedBox(height: 20),

                  // PDF Upload Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PDF File (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PDF will be stored directly in Firestore',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          if (_isPickingPdf)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Selecting PDF...'),
                                ],
                              ),
                            )
                          else if (_pdfFileName != null)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pdfFileName!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Size: ${(_pdfBytes!.length / 1024).toStringAsFixed(1)} KB',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: _removePdf,
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          if (!_isPickingPdf && _pdfFileName == null)
                            ElevatedButton.icon(
                              onPressed: _pickPDF,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Select PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                foregroundColor: Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Save Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }
}
