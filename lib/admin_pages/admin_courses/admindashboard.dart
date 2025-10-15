import 'package:fixem/admin_pages/admin_courses/create_course_page.dart';
import 'package:fixem/admin_pages/admin_courses/create_unit_page.dart';
import 'package:fixem/admin_pages/admin_courses/user_page.dart';
import 'package:fixem/employee_pages/create_job.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  // Statistics data
  int totalCourses = 0;
  int totalJobs = 0;
  int totalUnits = 0;
  int totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    // Get courses count
    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .get();

    // Get jobs count
    final jobsSnapshot = await FirebaseFirestore.instance
        .collection('jobs')
        .get();

    // Get users count
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    // Get total units count (across all courses)
    int unitsCount = 0;
    for (var course in coursesSnapshot.docs) {
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(course.id)
          .collection('units')
          .get();
      unitsCount += unitsSnapshot.docs.length;
    }

    setState(() {
      totalCourses = coursesSnapshot.docs.length;
      totalJobs = jobsSnapshot.docs.length;
      totalUnits = unitsCount;
      totalUsers = usersSnapshot.docs.length;
    });
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen and remove all routes
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  // Dashboard cards - now clickable
  Widget _buildStatsCard(
    String title,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
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
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, color: Colors.lightBlueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
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
          Expanded(child: Text(title)),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // Main dashboard view
  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
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
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage courses, jobs, and users',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statistics section
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
                'Total Courses',
                totalCourses,
                Icons.school,
                Colors.green,
                () => setState(() => _currentIndex = 1),
              ),
              _buildStatsCard(
                'Total Jobs',
                totalJobs,
                Icons.work,
                Colors.orange,
                () => setState(() => _currentIndex = 2),
              ),
              _buildStatsCard(
                'Total Users',
                totalUsers,
                Icons.people,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UsersPage()),
                ),
              ),
              _buildStatsCard(
                'Total Units',
                totalUnits,
                Icons.library_books,
                Colors.red,
                () => setState(() => _currentIndex = 1),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick Actions section - Removed Create Job
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              _buildQuickActionCard(
                'Create New Course',
                'Add a new learning course',
                Icons.add_circle_outline,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateCoursePage(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Create Learning Unit',
                'Add units to existing courses',
                Icons.library_add,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateUnitPage(),
                  ),
                ),
              ),
              // Removed Create Job quick action
            ],
          ),

          const SizedBox(height: 32),

          // Recent Activity section - Added back
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildActivityItem('New course created', '2 hours ago'),
                  _buildActivityItem('Job listing updated', '5 hours ago'),
                  _buildActivityItem('New unit added', '1 day ago'),
                  _buildActivityItem('User registration', '2 days ago'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Courses management view with course details
  Widget _buildCoursesView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courses'),
        backgroundColor: Colors.lightBlueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = 0),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('courses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No courses found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateCoursePage(),
                      ),
                    ),
                    child: const Text('Create First Course'),
                  ),
                ],
              ),
            );
          }

          final courses = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final data = course.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(
                    Icons.school,
                    color: Colors.lightBlueAccent,
                  ),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description'] ?? 'No description'),
                      const SizedBox(height: 4),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('courses')
                            .doc(course.id)
                            .collection('units')
                            .get(),
                        builder: (context, unitSnapshot) {
                          final unitCount = unitSnapshot.data?.docs.length ?? 0;
                          return Text(
                            '$unitCount unit${unitCount != 1 ? 's' : ''} • ${data['duration'] ?? 'No duration'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showCourseDetails(context, course.id, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Show course details (simplified - removed units display)
  void _showCourseDetails(
    BuildContext context,
    String courseId,
    Map<String, dynamic> courseData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(courseData['title'] ?? 'Course Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseData['description'] ?? 'No description available',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Duration:',
              courseData['duration'] ?? 'Not specified',
            ),
            _buildDetailRow('Badge:', courseData['badge'] ?? 'Not specified'),
            _buildDetailRow(
              'Matched Jobs:',
              courseData['matchedJobs'] ?? 'Not specified',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateUnitPage()),
              );
            },
            child: const Text('Add Unit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Jobs management view with improved design
  Widget _buildJobsView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Catalog'),
        backgroundColor: Colors.lightBlueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = 0),
        ),
      ),
      body: const ImprovedJobsView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: const Text('Admin Panel'),
              backgroundColor: Colors.lightBlueAccent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStatistics,
                ),
                IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
              ],
            )
          : null,
      body: _currentIndex == 0
          ? _buildDashboardView()
          : _currentIndex == 1
          ? _buildCoursesView()
          : _buildJobsView(),
      floatingActionButton: _currentIndex == 0
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_currentIndex == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateCoursePage(),
                    ),
                  );
                } else if (_currentIndex == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateJobPage(),
                    ),
                  );
                }
              },
              backgroundColor: Colors.lightBlueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      // Bottom Navigation Bar - Added back for all screens
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
        ],
      ),
    );
  }
}

// Improved Jobs View with better design
class ImprovedJobsView extends StatelessWidget {
  const ImprovedJobsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.work_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No jobs available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first job posting',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateJobPage(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Job'),
                  ),
                ],
              ),
            );
          }

          final jobs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final doc = jobs[index];
              final job = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              job['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              job['salary'] ?? 'Salary not set',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Job Description
                      Text(
                        job['description'] ?? 'No description available',
                        style: const TextStyle(color: Colors.grey, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Job Details
                      _buildJobDetail(
                        'Skills:',
                        job['skills'] ?? 'Not specified',
                      ),
                      _buildJobDetail(
                        'Location:',
                        job['location'] ?? 'Not specified',
                      ),
                      _buildJobDetail(
                        'Closing Date:',
                        job['closingdate'] ?? 'Not specified',
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Edit functionality would go here
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                bool? confirmed = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Deletion'),
                                    content: const Text(
                                      'Are you sure you want to delete this job?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(doc.id)
                                      .delete();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Job deleted successfully'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildJobDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
