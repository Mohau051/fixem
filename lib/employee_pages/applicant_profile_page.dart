import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ApplicantProfilePage extends StatefulWidget {
  final String applicantId;
  final String applicationId;
  final Map<String, dynamic> applicationData;

  const ApplicantProfilePage({
    super.key,
    required this.applicantId,
    required this.applicationId,
    required this.applicationData,
  });

  @override
  State<ApplicantProfilePage> createState() => _ApplicantProfilePageState();
}

class _ApplicantProfilePageState extends State<ApplicantProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _applicantProfile;
  List<Map<String, dynamic>> _applicantBadges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicantData();
  }

  Future<void> _loadApplicantData() async {
    try {
      // Load applicant profile
      final profileDoc = await _firestore
          .collection('users')
          .doc(widget.applicantId)
          .get();

      if (profileDoc.exists) {
        setState(() {
          _applicantProfile = profileDoc.data()!;
        });
      }

      // Load applicant badges
      final badgesSnapshot = await _firestore
          .collection('user_badges')
          .doc(widget.applicantId)
          .collection('badges')
          .orderBy('awardedAt', descending: true)
          .get();

      setState(() {
        _applicantBadges = badgesSnapshot.docs
            .map((doc) => doc.data()..['id'] = doc.id)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading applicant data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateApplicationStatus(String status) async {
    try {
      await _firestore
          .collection('applications')
          .doc(widget.applicationId)
          .update({'status': status, 'updatedAt': Timestamp.now()});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application $status successfully')),
      );

      // Navigate back to applications page
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update application: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.applicationData;
    final status = application['status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applicant Profile'),
        backgroundColor: Colors.lightBlueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Application Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application Status: ${status.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(status),
                              ),
                            ),
                            Text(
                              'Applied for: ${application['jobTitle'] ?? 'Unknown Job'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        if (status == 'pending')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _updateApplicationStatus('approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () =>
                                    _updateApplicationStatus('rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Applicant Profile Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.lightBlueAccent,
                            child: Text(
                              _getInitials(
                                application['applicantName'] ??
                                    'Unknown Applicant',
                              ),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            application['applicantName'] ?? 'Unknown Applicant',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            application['applicantEmail'] ?? 'No email',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildProfileInfoRow(
                            Icons.phone,
                            'Phone',
                            application['applicantPhone'] ?? 'Not provided',
                          ),
                          _buildProfileInfoRow(
                            Icons.location_on,
                            'Location',
                            application['applicantLocation'] ?? 'Not provided',
                          ),
                          if (_applicantProfile?['province'] != null)
                            _buildProfileInfoRow(
                              Icons.map,
                              'Province',
                              _applicantProfile!['province'],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Skills
                  if (_applicantProfile?['skills'] != null &&
                      (_applicantProfile!['skills'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skills',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_applicantProfile!['skills'] as List)
                                  .map(
                                    (skill) => Chip(
                                      label: Text(skill.toString()),
                                      backgroundColor: Colors.lightBlueAccent
                                          .withOpacity(0.1),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Earned Badges
                  const Text(
                    'Earned Badges',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_applicantBadges.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No badges earned yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _applicantBadges
                          .map((badge) => _buildBadgeCard(badge))
                          .toList(),
                    ),

                  // Cover Letter
                  if (application['coverLetter'] != null &&
                      application['coverLetter'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Cover Letter',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              application['coverLetter'],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.lightBlueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge['badgeTitle'] ?? 'Unknown Badge',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge['courseTitle'] ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earned: ${_formatBadgeDate(badge['awardedAt'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatBadgeDate(dynamic date) {
    if (date is Timestamp) {
      final badgeDate = date.toDate();
      return '${badgeDate.day}/${badgeDate.month}/${badgeDate.year}';
    }
    return 'Unknown date';
  }
}
