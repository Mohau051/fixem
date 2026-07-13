import 'package:fixem/admin_pages/admin_courses/create_course_page.dart';
import 'package:fixem/admin_pages/admin_courses/create_unit_page.dart';
import 'package:fixem/employee_pages/create_job.dart';
import 'package:fixem/employee_pages/employeedashboard.dart';
import 'package:fixem/employee_pages/read_jobs.dart';
import 'package:fixem/jobseeker_pages/course_overview_page.dart';
import 'package:fixem/jobseeker_pages/learning_hub_page.dart';
import 'package:fixem/pages/career_chatbot_page.dart';
import 'package:fixem/pages/createprofile_page.dart';
import 'package:fixem/pages/edit_job.dart';
import 'package:fixem/pages/job_description.dart';
import 'package:fixem/pages/jobs_page.dart';
import 'package:fixem/pages/login_page.dart';
import 'package:fixem/pages/main_page.dart';
import 'package:fixem/pages/register_page.dart';
import 'package:fixem/pages/dashboard_page.dart';
import 'package:fixem/pages/profile_page.dart'; // Add this import
import 'package:flutter/material.dart';

class RouteManger {
  static const String homePage = '/';
  static const String registerpage = '/register';
  static const String login = '/login';
  static const String createProfile = '/CreateProfile';
  static const String profile = '/Profile'; // Add this route
  static const String dashboard = '/Dashboard';
  static const String employeeDashboard = '/EmployeeDashboard';
  static const String jobs = '/Jobs';
  static const String jobDescription = '/JobDescription';
  static const String createjob = '/CreateJob';
  static const String readjob = '/ReadJob';
  static const String editjob = '/EditJob';
  static const String learninghub = '/Learninghub';
  static const String quiz = '/Quiz';
  static const String courseoverview = '/CourseOverview';
  static const String createunit = '/CreateUnit';
  static const String createcourse = '/CreateCourse';
  static const String careerChatbot = '/CareerChatbot';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homePage:
        return MaterialPageRoute(builder: (context) => MainPage());

      case registerpage:
        return MaterialPageRoute(builder: (context) => RegisterPage());

      case login:
        return MaterialPageRoute(builder: (context) => LoginPage());

      case createProfile:
        final args = settings.arguments as Map<String, dynamic>?;
        final prefilledEmail = args?['prefilledEmail'] as String?;
        final prefilledRole = args?['prefilledRole'] as String?;
        return MaterialPageRoute(
          builder: (context) => CreatePage(
            prefilledEmail: prefilledEmail,
            prefilledRole: prefilledRole,
          ),
        );

      case profile: // Add this case
        return MaterialPageRoute(builder: (context) => ProfilePage());

      case dashboard:
        return MaterialPageRoute(builder: (context) => DashboardPage());

      case employeeDashboard:
        return MaterialPageRoute(builder: (context) => EmployeeDashboard());

      case jobs:
        return MaterialPageRoute(builder: (context) => JobsPage());

      case createjob:
        return MaterialPageRoute(builder: (context) => CreateJobPage());

      case jobDescription:
        final args = settings.arguments as Map<String, dynamic>;
        final jobId = args['jobId'] as String;
        return MaterialPageRoute(
          builder: (context) => JobDescriptionPage(jobId: jobId),
        );

      case readjob:
        return MaterialPageRoute(builder: (context) => ReadJobsPage());

      case editjob:
        final jobId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => EditJobPage(jobId: jobId),
        );

      case learninghub:
        return MaterialPageRoute(builder: (context) => LearningHubPage());

      case courseoverview:
        final args = settings.arguments as Map<String, dynamic>;
        final courseId = args['courseId'] as String;
        final courseTitle = args['courseTitle'] as String;
        return MaterialPageRoute(
          builder: (context) =>
              CourseOverviewPage(courseId: courseId, courseTitle: courseTitle),
        );

      case createunit:
        return MaterialPageRoute(builder: (context) => const CreateUnitPage());

      case createcourse:
        return MaterialPageRoute(
          builder: (context) => const CreateCoursePage(),
        );

      case careerChatbot:
        return MaterialPageRoute(
          builder: (context) => const CareerChatbotPage(),
        );

      default:
        throw FormatException('Route not found');
    }
  }
}
