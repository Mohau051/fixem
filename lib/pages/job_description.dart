import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class JobDescriptionPage extends StatefulWidget {
  final String jobId;

  const JobDescriptionPage({super.key, required this.jobId});

  @override
  State<JobDescriptionPage> createState() => _JobDescriptionPageState();
}

class _JobDescriptionPageState extends State<JobDescriptionPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _hasApplied = false;
  Map<String, dynamic>? _userProfile;
  final TextEditingController _coverLetterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkIfApplied();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userProfile = doc.data()!;
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _checkIfApplied() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final applicationSnapshot = await _firestore
            .collection('applications')
            .where('jobId', isEqualTo: widget.jobId)
            .where('applicantId', isEqualTo: user.uid)
            .get();

        setState(() {
          _hasApplied = applicationSnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking application status: $e');
    }
  }

  Future<void> _applyForJob() async {
    final user = _auth.currentUser;
    if (user == null || _userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your profile first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if already applied
      final existingApplication = await _firestore
          .collection('applications')
          .where('jobId', isEqualTo: widget.jobId)
          .where('applicantId', isEqualTo: user.uid)
          .get();

      if (existingApplication.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied for this job'),
          ),
        );
        return;
      }

      // Get job details
      final jobDoc = await _firestore
          .collection('jobs')
          .doc(widget.jobId)
          .get();
      final jobData = jobDoc.data()!;

      // Create application
      await _firestore.collection('applications').add({
        'jobId': widget.jobId,
        'jobTitle': jobData['title'],
        'jobEmployerId': jobData['employerId'],
        'applicantId': user.uid,
        'applicantName': '${_userProfile!['name']} ${_userProfile!['surname']}',
        'applicantEmail': _userProfile!['email'],
        'applicantPhone': _userProfile!['phone'],
        'applicantLocation': _userProfile!['province'],
        'coverLetter': _coverLetterController.text.trim(),
        'status': 'pending', // pending, approved, rejected
        'appliedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      setState(() => _hasApplied = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to apply: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showApplyDialog(Map<String, dynamic> jobData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Job'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                jobData['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cover Letter (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _coverLetterController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Tell the employer why you are a good fit for this position...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _applyForJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('SUBMIT APPLICATION'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Job not found.'));
          }

          final jobData = snapshot.data!.data() as Map<String, dynamic>;

          final title = jobData['title'] ?? 'No title';
          final location = jobData['location'] ?? 'Unknown location';
          final description =
              jobData['description'] ?? 'No description provided';
          final skills = jobData['skills'] ?? 'No skills listed';
          final salary = jobData['salary'] ?? 'Not specified';
          final closingDate = jobData['closingdate'] ?? 'Not specified';
          final type = jobData['type'] ?? 'N/A';

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              children: [
                // Job Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined),
                    const SizedBox(width: 5),
                    Text(location, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),

                // Job Description
                const Text(
                  'Job Description:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),

                // Skills
                const Text(
                  'Required Skills / Badge:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 5),
                Text(skills, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),

                // Salary
                const Text(
                  'Salary:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 5),
                Text(salary, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),

                // Closing Date
                const Text(
                  'Closing Date:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 5),
                Text(closingDate, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 30),

                // Apply Button
                if (_hasApplied)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Application Submitted!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your application has been sent to the employer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _showApplyDialog(jobData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'APPLY NOW',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }
}
