import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _matchedJobsController = TextEditingController();

  bool _isLoading = false;

  // Save course to Firestore
  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('courses').add({
        'title': _titleController.text.trim(),
        'duration': _durationController.text.trim(),
        'badge': _badgeController.text.trim(),
        'matchedJobs': _matchedJobsController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully!')),
      );

      Navigator.pop(context); // Go back to previous screen
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save course: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Course')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Course Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter course title' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter duration' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _badgeController,
                decoration: const InputDecoration(labelText: 'Badge Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter badge title' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _matchedJobsController,
                decoration: const InputDecoration(labelText: 'Matched Jobs'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter matched jobs' : null,
              ),
              const SizedBox(height: 20),

              // Save Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'SAVE COURSE',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
