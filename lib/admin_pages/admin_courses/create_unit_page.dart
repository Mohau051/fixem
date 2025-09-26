import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

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

  File? _selectedPdf;
  bool _isLoading = false;
  String? _selectedCourseId;

  // Load all courses from Firestore for dropdown
  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('courses')
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, 'title': doc['title']})
        .toList();
  }

  // Pick PDF from device
  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _selectedPdf = File(result.files.single.path!);
      });
    }
  }

  // Upload PDF to Storage and return download URL
  Future<String?> _uploadPdf(File file) async {
    final filename = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('unit_pdfs/$filename.pdf');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // Save unit to Firestore under the selected course
  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) return;

    setState(() => _isLoading = true);

    try {
      String? pdfUrl;
      if (_selectedPdf != null) {
        pdfUrl = await _uploadPdf(_selectedPdf!);
      }

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('units')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'youtubeUrl': _youtubeUrlController.text.trim(),
            'pdfUrl': pdfUrl ?? '',
            'createdAt': Timestamp.now(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit created successfully!')),
      );
      Navigator.pop(context); // Back to admin dashboard or course view
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save unit: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Unit')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCourses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final courses = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Course',
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

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Unit Title'),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter unit title' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Description',
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _youtubeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube Video URL',
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter YouTube link' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickPDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Upload PDF (Optional)'),
                  ),
                  if (_selectedPdf != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Selected PDF: ${_selectedPdf!.path.split('/').last}',
                      ),
                    ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _saveUnit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'SAVE UNIT',
                            style: TextStyle(color: Colors.white),
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
}
