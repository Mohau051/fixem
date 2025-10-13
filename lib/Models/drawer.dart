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
        Navigator.pushReplacementNamed(context, RouteManger.profile);
      } else {
        // User doesn't have a profile, navigate to create profile
        Navigator.pushReplacement(
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
      Navigator.pushReplacementNamed(context, RouteManger.createProfile);
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

            // LEARN
            _buildDrawerItem(
              context,
              icon: Icons.school_outlined,
              label: 'LEARN',
              onTap: () => Navigator.pushReplacementNamed(
                context,
                RouteManger.learninghub,
              ),
            ),

            // PROFILE - Updated to check if profile exists
            _buildDrawerItem(
              context,
              icon: Icons.person_outline,
              label: 'PROFILE',
              onTap: () => _navigateToProfile(context),
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
