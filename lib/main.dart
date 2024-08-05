import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Page imports
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'register_page.dart';
import 'mentordashboard.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduFlex',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // SplashScreen as the initial widget
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterPage(),
        '/dashboard': (context) => DashboardScreen(),
        '/mentordashboard': (context) => MentorDashboardScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final currentVersion = (await _getAppVersion()).split('+').first; // Remove build number
      final releaseUrl = 'https://api.github.com/repos/Soham01011/Eduflex/releases/latest';
      final response = await http.get(Uri.parse(releaseUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = (data['tag_name'] ?? '').replaceFirst('v', '').split('+').first; // Remove build number if any

        print("**********************$latestVersion***********$currentVersion");

        if (latestVersion != currentVersion) {
          final apkUrl = (data['assets'] as List<dynamic>)
              .firstWhere(
                (asset) => asset['name'] == 'app-release.apk',
            orElse: () => null,
          )?['browser_download_url'];

          if (apkUrl != null) {
            _launchURL(apkUrl);
          } else {
            _showSnackbar("No APK found in the latest release");
            _navigateToHome();
          }
        } else {
          _showSnackbar("App is up-to-date");
          _navigateToHome();
        }
      } else {
        _showSnackbar("Unable to fetch update information");
        _navigateToHome();
      }
    } catch (e) {
      print('Error checking for updates: $e');
      _showSnackbar("Error checking for updates");
      _navigateToHome();
    }
  }

  Future<String> _getAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version; // Return current version directly
  }


  void _launchURL(String url) async {
    final Uri apkUri = Uri.parse(url);
    if (!await launchUrl(apkUri)) {
      throw Exception('Could not launch $url');
    }
  }

  void _navigateToHome() {
    // Navigate to the initial route
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
