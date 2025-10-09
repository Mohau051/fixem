import 'package:fixem/admin_pages/admin_courses/create_course_page.dart';
import 'package:fixem/admin_pages/admin_courses/create_unit_page.dart';
import 'package:fixem/employee_pages/create_job.dart';
import 'package:fixem/employee_pages/read_jobs.dart';
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
                () => setState(() => _currentIndex = 1), // Navigate to Courses
              ),
              _buildStatsCard(
                'Total Jobs',
                totalJobs,
                Icons.work,
                Colors.orange,
                () => setState(() => _currentIndex = 2), // Navigate to Jobs
              ),
              _buildStatsCard(
                'Total Units',
                totalUnits,
                Icons.library_books,
                Colors.purple,
                () => setState(() => _currentIndex = 1), // Navigate to Courses
              ),
              _buildStatsCard(
                'Active Users',
                0,
                Icons.people,
                Colors.red,
                () {}, // Add user management later
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick Actions section - Removed job-related actions
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
              // Removed job-related quick actions
            ],
          ),

          const SizedBox(height: 32),

          // Recent Activity section
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

  // Courses management view with course details
  Widget _buildCoursesView() {
    return Column(
      children: [
        // Custom header for courses
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.lightBlueAccent,
          child: const Text(
            'Manage Courses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .snapshots(),
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
                              final unitCount =
                                  unitSnapshot.data?.docs.length ?? 0;
                              return Text(
                                '$unitCount unit${unitCount != 1 ? 's' : ''}',
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
        ),
      ],
    );
  }

  // Show course details with units
  void _showCourseDetails(
    BuildContext context,
    String courseId,
    Map<String, dynamic> courseData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  courseData['title'] ?? 'Course Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              courseData['description'] ?? 'No description available',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Course Units',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('courses')
                    .doc(courseId)
                    .collection('units')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('No units available'),
                          SizedBox(height: 8),
                          Text(
                            'Add units to this course',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final units = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      final unit = units[index];
                      final unitData = unit.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.library_books,
                            color: Colors.blue,
                          ),
                          title: Text(unitData['title'] ?? 'Untitled Unit'),
                          subtitle: Text(
                            unitData['description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: unitData['hasPdf'] == true
                              ? const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close the modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateUnitPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Unit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlueAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Jobs management view with proper header
  Widget _buildJobsView() {
    return Column(
      children: [
        // Custom header for jobs
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.lightBlueAccent,
          child: const Text(
            'Job Catalog',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child:
              ReadJobsPageWithoutAppBar(), // Use the modified version without AppBar
        ),
      ],
    );
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

// Modified version of ReadJobsPage without AppBar
class ReadJobsPageWithoutAppBar extends StatelessWidget {
  const ReadJobsPageWithoutAppBar({super.key});

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
            return const Center(child: Text('No jobs found.'));
          }

          final jobs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: jobs.map((doc) {
                final job = doc.data() as Map<String, dynamic>;

                return Container(
                  width: 300,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(job['description'] ?? 'No Description'),
                      const SizedBox(height: 10),
                      Text("Skills:\n${job['skills'] ?? 'None'}"),
                      const SizedBox(height: 10),
                      Text("Pay: ${job['salary'] ?? 'Not specified'}"),
                      const SizedBox(height: 10),
                      Text("Closing Date: ${job['closingdate'] ?? '-'}"),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // EDIT JOB button
                          ElevatedButton.icon(
                            onPressed: () {
                              // You'll need to import EditJobPage or adjust this
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (_) => EditJobPage(jobId: doc.id),
                              //   ),
                              // );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('EDIT JOB'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent,
                            ),
                          ),

                          // DELETE JOB button with confirmation
                          ElevatedButton.icon(
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
                            icon: const Icon(Icons.delete),
                            label: const Text('DELETE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
