import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/admin_pages/admin_courses/admindashboard.dart';
import 'package:fixem/auth/auth_service.dart';
import 'package:fixem/employee_pages/employeedashboard.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:flutter/material.dart';
import 'package:fixem/routes/routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters long';
    return null;
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = await _auth.loginUserWithEmailAndPassword(
          _email.trim(),
          _password.trim(),
        );

        if (user != null) {
          final email = user.email;

          if (email == 'adminfix@gmail.com') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          } else {
            final profileExists = await _auth.checkProfileExists(user.uid);

            if (profileExists) {
              final userProfile = await _auth.getUserProfile();
              final userRole = userProfile?['role'] ?? 'job_seeker';

              if (userRole == 'employee') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeDashboard(),
                  ),
                );
              } else {
                Navigator.of(
                  context,
                ).pushReplacementNamed(RouteManger.dashboard);
              }
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreatePage(prefilledEmail: _email.trim()),
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Please try again.')),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found for this email';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Try again later';
            break;
          default:
            errorMessage = 'Login failed. Please try again';
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
                  "WELCOME BACK",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.black,
                    fontFamily: 'Moulpali',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Image - made smaller and constrained
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 100,
                    maxHeight: 200,
                  ),
                  child: const Image(
                    image: AssetImage('assets/Images/login.png'),
                  ),
                ),
                const SizedBox(height: 20),

                // Email Field
                TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Enter your Email',
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
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Enter your Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                  validator: _validatePassword,
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 16),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Forgot password feature coming soon!'),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.lightBlueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Login Button
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _login,
                          child: const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(RouteManger.registerpage);
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
