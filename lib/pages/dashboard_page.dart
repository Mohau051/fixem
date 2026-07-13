import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/Models/drawer.dart';
import 'package:fixem/pages/career_chatbot_page.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/pages/job_description.dart';
import 'package:flutter/material.dart';
import 'package:fixem/jobseeker_pages/badges_pages.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _auth = AuthService();
  String? userName;
  List<Map<String, dynamic>> recommendedJobs = [];
  int _badgesCount = 0;
  bool _isLoadingBadges = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecommendedJobs();
    _loadBadgesCount();
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
          final data = doc.data();
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

  Future<void> _loadBadgesCount() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Method 1: Try to get from user_badges collection (more reliable)
      final badgesSnapshot = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(userId)
          .collection('badges')
          .get();

      final badgesCount = badgesSnapshot.docs.length;

      // Update the user document with the correct count
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'badgesCount': badgesCount,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      setState(() {
        _badgesCount = badgesCount;
        _isLoadingBadges = false;
      });
    } catch (e) {
      print('Error loading badges count: $e');

      // Fallback: Try to get from user document
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _badgesCount = data?['badgesCount'] ?? 0;
            _isLoadingBadges = false;
          });
        } else {
          setState(() {
            _badgesCount = 0;
            _isLoadingBadges = false;
          });
        }
      } catch (e2) {
        print('Error with fallback: $e2');
        setState(() {
          _badgesCount = 0;
          _isLoadingBadges = false;
        });
      }
    }
  }

  void _viewAllBadges() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BadgesPage()),
    );
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

            // ── Career Guidance Chatbot Card ──────────────────────────────
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CareerChatbotPage(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Career Guidance Chatbot',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Get CV tips, interview prep & job advice',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Badges & Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingBadges)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        children: [
                          // Badges Count and Progress
                          Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Badges Earned: $_badgesCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Progress indicator for visual appeal
                          LinearProgressIndicator(
                            value:
                                _badgesCount /
                                10, // Assuming 10 is max for visual scale
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _badgesCount > 0 ? Colors.amber : Colors.grey,
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete courses to earn more badges!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // View Badges Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _viewAllBadges,
                              icon: const Icon(
                                Icons.workspace_premium_outlined,
                              ),
                              label: const Text('VIEW ALL BADGES'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _badgesCount > 0
                                    ? Colors.amber[50]
                                    : Colors.grey[100],
                                foregroundColor: _badgesCount > 0
                                    ? Colors.amber[800]
                                    : Colors.grey[600],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
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
