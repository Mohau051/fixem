import 'package:fixem/admin_pages/admin_courses/create_course_page.dart';
import 'package:fixem/admin_pages/admin_courses/create_unit_page.dart';
import 'package:fixem/admin_pages/admin_jobs/create_job.dart';
import 'package:fixem/admin_pages/admin_jobs/read_jobs.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    });
  }

  // Dashboard cards
  Widget _buildStatsCard(String title, int count, IconData icon, Color color) {
    return Card(
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
                    'Manage your courses, jobs, and content',
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
              ),
              _buildStatsCard(
                'Total Jobs',
                totalJobs,
                Icons.work,
                Colors.orange,
              ),
              _buildStatsCard(
                'Total Units',
                totalUnits,
                Icons.library_books,
                Colors.purple,
              ),
              _buildStatsCard(
                'Active Users',
                0,
                Icons.people,
                Colors.red,
              ), // You can add user count later
            ],
          ),

          const SizedBox(height: 32),

          // Quick Actions section
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
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Post New Job',
                'Create a new job listing',
                Icons.work_outline,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateJobPage(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Manage Jobs',
                'View and edit job listings',
                Icons.manage_search,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReadJobsPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recent Activity section (optional - you can expand this later)
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
                  // You can add recent activity items here
                  _buildActivityItem('New course created', '2 hours ago'),
                  _buildActivityItem('Job listing updated', '5 hours ago'),
                  _buildActivityItem('New unit added', '1 day ago'),
                ],
              ),
            ),
          ),
        ],
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

  // Courses management view
  Widget _buildCoursesView() {
    return StreamBuilder<QuerySnapshot>(
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
              child: ListTile(
                leading: const Icon(
                  Icons.school,
                  color: Colors.lightBlueAccent,
                ),
                title: Text(data['title'] ?? 'No Title'),
                subtitle: Text('Duration: ${data['duration'] ?? 'N/A'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    // Navigate to course details or edit page
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Jobs management view
  Widget _buildJobsView() {
    return const ReadJobsPage(); // Reuse your existing jobs page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.lightBlueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Implement logout functionality
            },
          ),
        ],
      ),
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
