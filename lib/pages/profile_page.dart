import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
              'Location',
              userProfile!['location'] ?? 'Not specified',
            ),

            // Skills Section (for job seekers)
            if (userProfile!['role'] == 'job_seeker') ...[
              const SizedBox(height: 24),
              const Text(
                'Skills',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
}
