import 'package:fixem/jobseeker_pages/badges_pages.dart';
import 'package:flutter/material.dart';
import 'package:fixem/routes/routes.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/pages/createprofile_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Function to handle profile navigation
  Future<void> _navigateToProfile(BuildContext context) async {
    try {
      final AuthService auth = AuthService();
      final userProfile = await auth.getUserProfile();

      if (userProfile != null && userProfile['name'] != null) {
        // User has a profile, navigate to profile view page
        Navigator.pushNamed(context, RouteManger.profile);
      } else {
        // User doesn't have a profile, navigate to create profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreatePage(prefilledEmail: auth.currentUser?.email),
          ),
        );
      }
    } catch (e) {
      print('Error checking profile: $e');
      // Fallback: navigate to create profile
      Navigator.pushNamed(context, RouteManger.createProfile);
    }
  }

  // Function to handle sign out
  Future<void> _signOut(BuildContext context) async {
    try {
      final AuthService auth = AuthService();
      await auth.signOut();
      // Navigate to login screen and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteManger.login,
        (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.lightBlue, // Soft blue background
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
          children: [
            const Text(
              'FIXEM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Moulpali',
              ),
            ),
            const SizedBox(height: 40),

            // HOME
            _buildDrawerItem(
              context,
              icon: Icons.home,
              label: 'HOME',
              onTap: () => Navigator.pushReplacementNamed(
                context,
                RouteManger.dashboard,
              ),
            ),

            // JOBS
            _buildDrawerItem(
              context,
              icon: Icons.work_outline,
              label: 'JOBS',
              onTap: () => Navigator.pushNamed(context, RouteManger.jobs),
            ),

            // LEARN - FIXED: Use pushNamed instead of pushReplacementNamed
            _buildDrawerItem(
              context,
              icon: Icons.school_outlined,
              label: 'LEARN',
              onTap: () =>
                  Navigator.pushNamed(context, RouteManger.learninghub),
            ),

            // BADGES - NEW: Add badges navigation
            _buildDrawerItem(
              context,
              icon: Icons.workspace_premium_outlined,
              label: 'MY BADGES',
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BadgesPage()),
                );
              },
            ),

            // PROFILE - Updated to check if profile exists
            _buildDrawerItem(
              context,
              icon: Icons.person_outline,
              label: 'PROFILE',
              onTap: () => _navigateToProfile(context),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white54),
            const SizedBox(height: 20),

            // SIGN OUT
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              label: 'SIGN OUT',
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
