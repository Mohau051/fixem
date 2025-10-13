import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _userType = 'Job Seeker';
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final List<String> _userTypes = ['Job Seeker', 'Employer'];

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter an email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _password) return 'Passwords do not match';
    return null;
  }

  String _getDatabaseRole(String userType) {
    switch (userType) {
      case 'Employer':
        return 'employee';
      case 'Job Seeker':
      default:
        return 'job_seeker';
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = await _auth.registerUserWithEmailAndPassword(
          _email.trim(),
          _password.trim(),
        );

        if (user != null) {
          final databaseRole = _getDatabaseRole(_userType);

          // Wait a moment for Firebase to fully initialize the user
          await Future.delayed(const Duration(milliseconds: 500));

          // Get the current user again to ensure we have the latest data
          final currentUser = FirebaseAuth.instance.currentUser;

          if (currentUser != null) {
            // Use the email from the authenticated user to avoid mismatch
            final authenticatedEmail = currentUser.email ?? _email.trim();

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePage(
                  prefilledEmail: authenticatedEmail,
                  prefilledRole: databaseRole,
                ),
              ),
            );
          } else {
            // Fallback: use the form email if currentUser is null
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePage(
                  prefilledEmail: _email.trim(),
                  prefilledRole: databaseRole,
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration failed. Try again.')),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'Email is already in use';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak';
            break;
          default:
            errorMessage = 'Registration failed. Please try again';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'WELCOME ON BOARD',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.black,
                    fontFamily: 'Moulpali',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Register as ${_userType.toLowerCase()}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // User Type Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Register as',
                    prefixIcon: const Icon(Icons.person_outline),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  value: _userType,
                  items: _userTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            type == 'Employer'
                                ? Icons.business_center
                                : Icons.person,
                            color: Colors.lightBlueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(type),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _userType = newValue!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a user type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // User Type Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _userType == 'Employer'
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.lightBlueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _userType == 'Employer'
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.lightBlueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _userType == 'Employer'
                            ? Icons.business_center
                            : Icons.work,
                        color: _userType == 'Employer'
                            ? Colors.orange
                            : Colors.lightBlueAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _userType == 'Employer'
                              ? 'You will be able to post jobs and hire talent'
                              : 'You will be able to browse jobs and take courses',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Email Field
                TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  onChanged: (value) => _email = value,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: _validatePassword,
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        );
                      },
                    ),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  validator: _validateConfirmPassword,
                  onChanged: (value) => _confirmPassword = value,
                ),
                const SizedBox(height: 30),

                // Register Button
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _userType == 'Employer'
                                ? Colors.orange
                                : Colors.lightBlueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _register,
                          child: Text(
                            'REGISTER AS $_userType'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Login Link
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(color: Colors.lightBlueAccent),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
