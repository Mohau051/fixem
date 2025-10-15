import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/employee_pages/create_job.dart';
import 'package:fixem/employee_pages/read_jobs.dart';
import 'package:fixem/employee_pages/applications_page.dart';
import 'package:flutter/material.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentIndex = 0;
  String? userName;
  int totalJobs = 0;
  int applicationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStatistics();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          userName = '${userDoc['name']} ${userDoc['surname']}';
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('employerId', isEqualTo: currentUser.uid)
          .get();

      final applicationsSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('jobEmployerId', isEqualTo: currentUser.uid)
          .get();

      setState(() {
        totalJobs = jobsSnapshot.docs.length;
        applicationsCount = applicationsSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  // Statistics Cards - Now opens in new screen instead of switching tabs
  Widget _buildStatsCard(
    String title,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Action Cards
  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.lightBlueAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.lightBlueAccent),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // Navigation methods
  void _navigateToCreateJob() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateJobPage()),
    );
  }

  void _navigateToManageJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadJobsPage()),
    );
  }

  void _navigateToApplications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplicationsPage()),
    );
  }

  // FIXED: Navigate to Jobs screen instead of switching tabs
  void _navigateToJobsFromOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadJobsPage()),
    );
  }

  void _navigateToApplicationsFromOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplicationsPage()),
    );
  }

  // Jobs Management View
  Widget _buildJobsView() {
    return const ReadJobsPage();
  }

  // Profile View
  Widget _buildProfileView() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Profile not found'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.lightBlueAccent,
                        child: Text(
                          '${userData['name']?[0] ?? 'E'}${userData['surname']?[0] ?? 'M'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${userData['name']} ${userData['surname']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userData['email'] ?? 'No email',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileItem(
                        'Phone',
                        userData['phone'] ?? 'Not provided',
                      ),
                      _buildProfileItem(
                        'Location',
                        userData['province'] ?? 'Not provided',
                      ),
                      _buildProfileItem(
                        'Gender',
                        userData['gender'] ?? 'Not provided',
                      ),
                      _buildProfileItem(
                        'Age',
                        userData['age']?.toString() ?? 'Not provided',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 0
            ? const Text('Employee Dashboard')
            : _currentIndex == 1
            ? const Text('Job Management')
            : const Text('Profile'),
        backgroundColor: Colors.lightBlueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _currentIndex == 0
          ? _buildDashboardView()
          : _currentIndex == 1
          ? _buildJobsView()
          : _buildProfileView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _navigateToCreateJob,
              backgroundColor: Colors.lightBlueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // Main Dashboard View
  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Card(
            elevation: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.lightBlueAccent, Colors.blue.shade700],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${userName ?? "Employee"}!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your job listings and track applications',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Section
          const Text(
            'Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatsCard(
                'Total Jobs',
                totalJobs,
                Icons.work,
                Colors.green,
                _navigateToJobsFromOverview, // FIXED: Now opens in new screen
              ),
              _buildStatsCard(
                'Applications',
                applicationsCount,
                Icons.people,
                Colors.purple,
                _navigateToApplicationsFromOverview,
              ),
              _buildStatsCard(
                'This Month',
                0,
                Icons.trending_up,
                Colors.red,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Monthly statistics coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick Actions Section
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              _buildQuickActionCard(
                'Post New Job',
                'Create a new job listing',
                Icons.add_business,
                _navigateToCreateJob,
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Manage Jobs',
                'View and edit job listings',
                Icons.manage_search,
                _navigateToManageJobs,
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'View Applications',
                'Check job applications',
                Icons.people_alt,
                _navigateToApplications,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recent Jobs Section
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Job Listings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('jobs')
                        .where(
                          'employerId',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                        )
                        .orderBy('createdAt', descending: true)
                        .limit(3)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No jobs posted yet.'),
                        );
                      }

                      final jobs = snapshot.data!.docs;

                      return Column(
                        children: jobs.map((doc) {
                          final job = doc.data() as Map<String, dynamic>;
                          return _buildRecentJobItem(job);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobItem(Map<String, dynamic> job) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.lightBlueAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Location: ${job['location'] ?? 'Not specified'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(job['createdAt']),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
