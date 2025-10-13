import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixem/routes/routes.dart';
import 'package:flutter/material.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _salaryAmountController = TextEditingController();
  final TextEditingController _closingDateController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String _selectedSalaryType = 'per month'; // Default value
  DateTime? _selectedClosingDate;

  // Salary type options
  final List<String> _salaryTypes = [
    'per hour',
    'per day',
    'per week',
    'per month',
    'per year',
    'per work done',
    'negotiable',
  ];

  Future<void> _selectClosingDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedClosingDate = picked;
        _closingDateController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _submitJob() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClosingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a closing date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create a job'),
          ),
        );
        return;
      }

      // Get employer profile data
      final employerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final employerData = employerDoc.data();
      final employerName = employerData != null
          ? '${employerData['name']} ${employerData['surname']}'
          : 'Unknown Employer';

      // Format salary with type
      final salaryAmount = _salaryAmountController.text.trim();
      final formattedSalary = 'R $salaryAmount $_selectedSalaryType';

      await FirebaseFirestore.instance.collection('jobs').add({
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'skills': _skillsController.text.trim(),
        'description': _descriptionController.text.trim(),
        'salary': formattedSalary,
        'salaryAmount': salaryAmount,
        'salaryType': _selectedSalaryType,
        'closingdate': _closingDateController.text.trim(),
        'closingDateTimestamp': Timestamp.fromDate(_selectedClosingDate!),
        'employerId': currentUser.uid, // CRITICAL: Add employer ID
        'employerName': employerName, // Add employer name for display
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job created successfully!')),
      );

      // Navigate to JobsPage after successful creation
      Navigator.pushReplacementNamed(context, RouteManger.readjob);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save job: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Job'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Create Job',
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.black,
                  fontFamily: 'Moulpali',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Fill in the details below to post a new job opportunity',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Job Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter job title' : null,
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter location' : null,
              ),
              const SizedBox(height: 16),

              // Required Skills
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Required Skills',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.psychology_outlined),
                  hintText: 'e.g., JavaScript, Python, Project Management',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter skills' : null,
              ),
              const SizedBox(height: 16),

              // Salary Section
              Row(
                children: [
                  // Salary Amount
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _salaryAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salary Amount',
                        border: OutlineInputBorder(),
                        prefixText: 'R ',
                        hintText: 'e.g., 15000',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter salary'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Salary Type Dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSalaryType,
                      decoration: const InputDecoration(
                        labelText: 'Per',
                        border: OutlineInputBorder(),
                      ),
                      items: _salaryTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSalaryType = newValue!;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Select salary type' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Closing Date - Date Picker
              TextFormField(
                controller: _closingDateController,
                readOnly: true, // Prevent manual editing
                decoration: InputDecoration(
                  labelText: 'Closing Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _selectClosingDate,
                  ),
                  hintText: 'Select closing date',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Select closing date'
                    : null,
                onTap: _selectClosingDate,
              ),
              const SizedBox(height: 16),

              // Job Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Job Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText:
                      'Describe the job responsibilities, requirements, and what you\'re looking for in a candidate...',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 30),

              // Submit Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'PUBLISH JOB',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    _descriptionController.dispose();
    _salaryAmountController.dispose();
    _closingDateController.dispose();
    super.dispose();
  }
}
