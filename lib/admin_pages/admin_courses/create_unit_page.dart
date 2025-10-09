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

  // Pick PDF from device
  Future<void> _pickPDF() async {
    if (_isPickingPdf) return;

    setState(() => _isPickingPdf = true);

    try {
      print('Starting PDF pick process...');

      // Pick file
      print('Opening file picker...');
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
          allowCompression: true,
        );
        print(
          'File picker completed. Result: ${result != null ? "File selected" : "Cancelled"}',
        );
      } catch (e) {
        print('FilePicker error details: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: ${e.toString()}')),
        );
        return;
      }

      // Process selected file
      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        print('Selected file details:');
        print('- Name: ${platformFile.name}');
        print('- Size: ${platformFile.size}');
        print('- Extension: ${platformFile.extension}');
        print('- Bytes available: ${platformFile.bytes != null}');

        // Verify it's a PDF file
        if (!platformFile.name.toLowerCase().endsWith('.pdf')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a PDF file (.pdf extension)'),
            ),
          );
          return;
        }

        // Check if bytes are available
        if (platformFile.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read PDF file content')),
          );
          return;
        }

        // Store the file data
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
      } else {
        print('No file selected or file selection cancelled');
      }
    } catch (e) {
      print('Unexpected error in _pickPDF: $e');
      print('Error type: ${e.runtimeType}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting PDF: ${e.toString()}')),
      );
    } finally {
      setState(() => _isPickingPdf = false);
    }
  }

  // Handle PDF upload - Store PDF data directly in Firestore
  Future<(bool success, String message, Map<String, dynamic> pdfData)>
  _handlePdfUpload() async {
    try {
      if (_pdfBytes == null || _pdfFileName == null) {
        return Future.value((
          false,
          "No PDF file selected",
          <String, dynamic>{},
        ));
      }

      // File size limit check (10MB like in C#)
      if (_pdfBytes!.length > 10 * 1024 * 1024) {
        return Future.value((
          false,
          "File size exceeds 10MB limit",
          <String, dynamic>{},
        ));
      }

      // File type validation
      if (!_pdfFileName!.toLowerCase().endsWith('.pdf')) {
        return Future.value((
          false,
          "Invalid file type. Only PDF files are allowed",
          <String, dynamic>{},
        ));
      }

      // Instead of saving to local storage, we'll store the PDF data in Firestore
      final pdfData = <String, dynamic>{
        'fileName': _pdfFileName,
        'fileSize': _pdfBytes!.length,
        'uploadedAt': Timestamp.now(),
        'hasPdf': true,
      };

      return Future.value((true, "PDF ready for upload", pdfData));
    } catch (e) {
      print('Error in _handlePdfUpload: $e');
      return Future.value((
        false,
        "Error processing PDF: ${e.toString()}",
        <String, dynamic>{},
      ));
    }
  }

  // Convert bytes to base64 string
  String _bytesToBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  // Convert base64 string back to bytes (for retrieval)
  Uint8List _base64ToBytes(String base64String) {
    return base64.decode(base64String);
  }

  // Save unit to Firestore
  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> pdfData = {};
      String? pdfBase64;

      // Handle PDF upload only when saving
      if (_pdfBytes != null && _pdfFileName != null) {
        print('=== Starting PDF upload process ===');

        // Try the direct storage approach first
        var (success, message, data) = await _handlePdfUpload();

        if (!success) {
          print('PDF upload failed: $message');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        pdfData = data;

        // Also store the PDF as base64 for direct access
        pdfBase64 = _bytesToBase64(_pdfBytes!);

        print('PDF successfully processed');
      }

      // Prepare unit data
      Map<String, dynamic> unitData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'youtubeUrl': _youtubeUrlController.text.trim(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      // Handle PDF data
      if (pdfData.isNotEmpty && pdfBase64 != null) {
        unitData.addAll({
          'pdfFileName': _pdfFileName,
          'pdfFileSize': _pdfBytes!.length,
          'pdfBase64': pdfBase64, // Store PDF content directly
          'hasPdf': true,
          'uploadedAt': Timestamp.now(),
        });
        print('Unit data includes PDF: ${_pdfFileName}');
      } else {
        unitData.addAll({
          'pdfFileName': '',
          'pdfFileSize': 0,
          'pdfBase64': '',
          'hasPdf': false,
        });
        print('Unit data does not include PDF');
      }

      // Save to Firestore
      print('Saving unit to Firestore...');
      final docRef = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('units')
          .add(unitData);

      // Generate numeric ID
      final numericId = docRef.id.hashCode.abs() % 100000000;

      // Update with numeric ID
      await docRef.update({'numericId': numericId});

      print('Unit saved successfully to Firestore with ID: ${docRef.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unit created successfully!'),
          duration: const Duration(seconds: 3),
        ),
      );

      // Clear form after successful save
      _clearForm();
    } catch (e) {
      print('Error saving unit: $e');
      print('Error type: ${e.runtimeType}');
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
        backgroundColor: Colors.blueAccent,
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
                      labelText: 'YouTube Video URL *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.video_library),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter YouTube link' : null,
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
                                          Text(
                                            'Will be stored in Firestore',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[700],
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
