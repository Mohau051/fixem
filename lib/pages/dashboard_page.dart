import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/Models/drawer.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/pages/job_description.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _auth = AuthService();
  String? userName;
  List<Map<String, dynamic>> recommendedJobs = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecommendedJobs();
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await _auth.getUserProfile();

      if (userProfile != null && userProfile['name'] != null) {
        setState(() {
          userName = '${userProfile['name']} ${userProfile['surname']}';
        });
      } else {
        // If no profile found, redirect to create profile
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePage(
                prefilledEmail: FirebaseAuth.instance.currentUser?.email,
              ),
            ),
          );
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadRecommendedJobs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      setState(() {
        recommendedJobs = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'location': data['location'] ?? 'Location not specified',
            'requiredBadge': data['skills'] ?? 'No specific badge required',
            'salary': data['salary'] ?? 'Not specified',
            'description': data['description'] ?? 'No description available',
            'closingDate': data['closingdate'] ?? 'Not specified',
            'employerId': data['employerId'] ?? '',
            'company': data['company'] ?? 'Not specified',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(job['location']),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.work, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Skills: ${job['requiredBadge']}',
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Salary: ${job['salary']}',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _viewJobDetails(job['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('VIEW JOB'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewJobDetails(String jobId) {
    // Navigate to your existing JobDescriptionPage
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobDescriptionPage(jobId: jobId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${userName ?? "User"}',
              style: const TextStyle(
                fontSize: 30,
                color: Colors.black,
                fontFamily: 'Moulpali',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'JOBS YOU MAY LIKE',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),

            // Recommended Jobs List
            Expanded(
              child: recommendedJobs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('No jobs available at the moment'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: recommendedJobs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildJobCard(recommendedJobs[index]),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // Badges Section
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('user_progress')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .collection('completed_courses')
                          .doc('summary')
                          .get(),
                      builder: (context, snapshot) {
                        int completedCourses = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          completedCourses = snapshot.data!['count'] ?? 0;
                        }

                        return Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Badges Earned: $completedCourses',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
