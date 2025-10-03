import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixem/jobseeker_pages/course_overview_page.dart';
import 'package:flutter/material.dart';

class LearningHubPage extends StatelessWidget {
  const LearningHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final coursesRef = FirebaseFirestore.instance.collection('courses');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Learning Hub"),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: coursesRef.snapshots(),
          builder: (context, snapshot) {
            // 🔄 Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // ❌ Error or empty
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No courses available."));
            }

            // ✅ Data fetched
            final courses = snapshot.data!.docs;

            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final courseData =
                    courses[index].data() as Map<String, dynamic>;
                final courseId = courses[index].id;
                final title = courseData['title'] ?? 'Untitled Course';
                final description = courseData['description'] ?? '';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(description, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CourseOverviewPage(courseId: courseId),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent,
                            ),
                            child: const Text("Start Course"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
