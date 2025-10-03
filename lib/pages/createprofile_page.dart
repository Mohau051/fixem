import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/routes/routes.dart';
import 'package:flutter/material.dart';

class CreatePage extends StatefulWidget {
  final String? prefilledEmail;

  const CreatePage({super.key, this.prefilledEmail});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Text controllers
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _provinceController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedProvince;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prefill email if provided
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  // Save data to Firestore using the same UID from Authentication
  Future<void> _createProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final User? user = _auth.currentUser;

        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated. Please log in again.'),
            ),
          );
          return;
        }

        // Verify the email matches the authenticated user
        if (_emailController.text.trim() != user.email) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email does not match authenticated user.'),
            ),
          );
          return;
        }

        // Create user profile with the same UID from Authentication
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid) // Use the exact same UID from Firebase Auth
            .set({
              'email': _emailController.text.trim(),
              'name': _nameController.text.trim(),
              'surname': _surnameController.text.trim(),
              'age': _ageController.text.trim(),
              'gender': _selectedGender ?? _genderController.text.trim(),
              'province': _selectedProvince ?? _provinceController.text.trim(),
              'phone': _phoneController.text.trim(),
              'userId': user.uid, // Store UID as a field for easy querying
              'authProvider': 'email_password', // Track auth method
              'createdAt': Timestamp.now(),
              'updatedAt': Timestamp.now(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created successfully!')),
        );

        // Navigate to dashboard
        Navigator.of(context).pushReplacementNamed(RouteManger.dashboard);
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore error: ${e.message}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create profile: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _provinceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Text(
                'COMPLETE YOUR PROFILE',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.black,
                  fontFamily: 'Moulpali',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please fill in your details to get started',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Email (read-only, from authentication)
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration('Email Address'),

                style: TextStyle(
                  color: Colors.grey[600], // Visual indication it's locked
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('First Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value!.isEmpty) return 'First name is required';
                  if (value.length < 2)
                    return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Surname
              TextFormField(
                controller: _surnameController,
                decoration: _inputDecoration('Last Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value!.isEmpty) return 'Last name is required';
                  if (value.length < 2)
                    return 'Surname must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Age
              TextFormField(
                controller: _ageController,
                decoration: _inputDecoration('Age'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Age is required';
                  final age = int.tryParse(value);
                  if (age == null || age < 16 || age > 100) {
                    return 'Please enter a valid age (16-100)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Gender - Dropdown (Improved)
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Gender'),
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                  DropdownMenuItem(
                    value: 'Prefer not to say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select your gender' : null,
              ),
              const SizedBox(height: 20),

              // Province - Dropdown (Improved)
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Province'),
                value: _selectedProvince,
                items: const [
                  DropdownMenuItem(
                    value: 'Eastern Cape',
                    child: Text('Eastern Cape'),
                  ),
                  DropdownMenuItem(
                    value: 'Free State',
                    child: Text('Free State'),
                  ),
                  DropdownMenuItem(value: 'Gauteng', child: Text('Gauteng')),
                  DropdownMenuItem(
                    value: 'KwaZulu-Natal',
                    child: Text('KwaZulu-Natal'),
                  ),
                  DropdownMenuItem(value: 'Limpopo', child: Text('Limpopo')),
                  DropdownMenuItem(
                    value: 'Mpumalanga',
                    child: Text('Mpumalanga'),
                  ),
                  DropdownMenuItem(
                    value: 'North West',
                    child: Text('North West'),
                  ),
                  DropdownMenuItem(
                    value: 'Northern Cape',
                    child: Text('Northern Cape'),
                  ),
                  DropdownMenuItem(
                    value: 'Western Cape',
                    child: Text('Western Cape'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select your province' : null,
              ),
              const SizedBox(height: 20),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: _inputDecoration('Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value!.isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^[0-9+]{10,13}$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Create Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _createProfile,
                      child: const Text(
                        'CREATE PROFILE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.lightBlueAccent),
      ),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      floatingLabelStyle: const TextStyle(color: Colors.lightBlueAccent),
    );
  }
}
