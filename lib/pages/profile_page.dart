import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/jobseeker_pages/badges_pages.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  int _badgesCount = 0;
  List<Map<String, dynamic>> _earnedBadges = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserBadges();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _auth.getUserProfile();
      if (profile != null && profile['name'] != null) {
        setState(() {
          userProfile = profile;
          _isLoading = false;
        });
      } else {
        // No profile found, redirect to create profile
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
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserBadges() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Load badges count from user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _badgesCount = userDoc.data()?['badgesCount'] ?? 0;
        });
      }

      // Load recent badges for display
      final badgesSnapshot = await FirebaseFirestore.instance
          .collection('user_badges')
          .doc(userId)
          .collection('badges')
          .orderBy('awardedAt', descending: true)
          .limit(3) // Show only 3 recent badges
          .get();

      setState(() {
        _earnedBadges = badgesSnapshot.docs
            .map((doc) => doc.data()..['id'] = doc.id)
            .toList();
      });
    } catch (e) {
      print('Error loading badges: $e');
    }
  }

  Future<void> _editProfile() async {
    // Navigate to edit profile page or create profile page in edit mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePage(
          prefilledEmail: userProfile?['email'],
          prefilledRole: userProfile?['role'],
          isEditing: true, // Add this parameter to your CreatePage
          existingProfile: userProfile,
        ),
      ),
    );

    // Reload profile if updated
    if (result == true) {
      _loadUserProfile();
    }
  }

  void _viewAllBadges() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BadgesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No profile found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Simply pop the current route to go back
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.lightBlueAccent,
                    child: Text(
                      userProfile!['name'] != null
                          ? '${userProfile!['name']![0]}${userProfile!['surname']![0]}'
                          : 'U',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${userProfile!['name']} ${userProfile!['surname']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userProfile!['email'] ?? 'No email',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Personal Information
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoCard('Role', userProfile!['role'] ?? 'Not specified'),
            _buildInfoCard('Phone', userProfile!['phone'] ?? 'Not specified'),
            _buildInfoCard(
              'Province',
              userProfile!['province'] ??
                  'Not specified', // Now using 'province' field
            ),

            // Skills & Badges Section (for job seekers)
            if (userProfile!['role'] == 'job_seeker') ...[
              const SizedBox(height: 24),
              const Text(
                'Skills & Badges',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Badges Summary Card
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Earned Badges',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Chip(
                            label: Text('$_badgesCount'),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            avatar: const Icon(
                              Icons.workspace_premium,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_earnedBadges.isEmpty)
                        const Text(
                          'No badges yet. Complete courses to earn badges!',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Column(
                          children: [
                            // Recent Badges
                            ..._earnedBadges.map(
                              (badge) => _buildBadgePreview(badge),
                            ),
                            const SizedBox(height: 12),

                            // View All Badges Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _viewAllBadges,
                                icon: const Icon(
                                  Icons.workspace_premium_outlined,
                                ),
                                label: const Text('VIEW ALL BADGES'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber[800],
                                  side: BorderSide(
                                    color: Colors.amber.withOpacity(0.5),
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

              const SizedBox(height: 16),

              // Skills List
              _buildSkillsList(),
            ],

            // Company Information (for employers)
            if (userProfile!['role'] == 'employee') ...[
              const SizedBox(height: 24),
              const Text(
                'Company Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                'Company Name',
                userProfile!['companyName'] ?? 'Not specified',
              ),
              _buildInfoCard(
                'Industry',
                userProfile!['industry'] ?? 'Not specified',
              ),
            ],

            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _editProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsList() {
    final skills = userProfile!['skills'] is List
        ? List<String>.from(userProfile!['skills'] ?? [])
        : <String>[];

    if (skills.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No skills added yet'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (skill) => Chip(
              label: Text(skill),
              backgroundColor: Colors.lightBlueAccent.withOpacity(0.1),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBadgePreview(Map<String, dynamic> badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge['badgeTitle'] ?? 'Unknown Badge',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  badge['courseTitle'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
