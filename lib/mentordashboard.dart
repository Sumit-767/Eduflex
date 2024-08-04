import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MentorDashboardScreen extends StatefulWidget {
  @override
  _MentorDashboardScreenState createState() => _MentorDashboardScreenState();
}


class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ProfilePage(),
    PostPermissionPage(),
    MentorGroupPage(),
    SettingsPage(),
    GoodiesPage(),
    LogoutPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('Menu'),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              title: Text('Home'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              title: Text('Profile'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              title: Text('Post Permission'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              title: Text('Mentor Group'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              title: Text('Settings'),
              onTap: () => _onItemTapped(4),
            ),
            ListTile(
              title: Text('Goodies'),
              onTap: () => _onItemTapped(5),
            ),
            ListTile(
              title: Text('Logout'),
              onTap: () => _onItemTapped(6),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(child: Text('Mentor Page')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(child: Text('Profile Page')),
    );
  }
}

class PostPermissionPage extends StatefulWidget{
  @override
  _PostPermissionPageState createState() => _PostPermissionPageState();
}

class _PostPermissionPageState extends State<PostPermissionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students posts'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(child: Text('Allow posts')),
    );
  }
}

class MentorGroupPage extends StatefulWidget{
  @override
  _MentorGroupPageState createState() => _MentorGroupPageState();
}

class _MentorGroupPageState extends State<MentorGroupPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _selectioncriteria = TextEditingController();
  final _storage = FlutterSecureStorage();
  File? _selectedFile;

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'pdf', 'doc','jpeg','jpg','png'],
    );

    if (result != null) {
      setState(() {
       _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadFile(BuildContext context) async {
    if ( _selectedFile == null) return;

    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.31.28:8000/upload'), // Replace with your API URL
    );

    request.fields['Token'] = token!;
    request.fields['post_type'] = 'mentor_file_upload';
    request.fields['post_desc'] = _descriptionController.text;
    request.fields['selection'] = _selectioncriteria.text;
    request.fields['up_username'] = username!;
    request.fields['interface'] = 'Mobileapp';



    request.files.add(await http.MultipartFile.fromPath(
      'file',
      _selectedFile!.path,
      filename: (_selectedFile!.path),
    ));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        print('File uploaded successfully');
        setState(() {
          _selectedFile = null;
          _descriptionController.clear();
        });
        Navigator.pop(context); // Close the modal after successful upload
      } else {
        print('Failed to upload file');
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  void _showUploadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.attach_file),
                title: Text('Select File'),
                onTap: _pickFile,
              ),
              if (_selectedFile != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        'Selected File: ${path.basename(_selectedFile!.path)}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Batch Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _selectioncriteria,
                        decoration: InputDecoration(
                          labelText: 'Name / Moodle',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  _uploadFile(context);
                },
                child: Text('Upload'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Mentees'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(child: Text('welcome')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadModal(context),
        child: Icon(Icons.upload_file),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storage = FlutterSecureStorage();

  Future<void> _updateProfile() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final phone = _phoneController.text;
    final token = await _storage.read(key: 'auth_token');

    final response = await http.post(
        Uri.parse('http://192.168.31.28:8000/changeprofile'),
        headers: {
          'Content-Type' : 'application/json',
        },
        body: json.encode ({
          'Token': token,
          'changeemail': email,
          'changepwd': password,
          'changephoneno': phone,
          'interface': 'Mobileapp',
        })
    );

    final responseBody = json.decode(response.body);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseBody['message'])));
      await _storage.delete(key: 'auth_token');
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseBody['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'New Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'New Phone Number'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              child: Text('Update Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class GoodiesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Goodies'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(child: Text('Goodies Page')),
    );
  }
}

class LogoutPage extends StatefulWidget {
  @override
  _logoutState createState() => _logoutState();
}

class _logoutState extends State<LogoutPage> {
  final _storage = FlutterSecureStorage();

  Future<void> _logout() async {
    final token = await _storage.read(key: 'auth_token');
    final response = await http.post(
        Uri.parse('http://192.168.31.28:8000/logout'),
        headers: {
          'Content-Type' : 'application/json',
        },
        body: json.encode ({
          'Token': token,
          'interface': 'Mobileapp',
        })
    );

    final responseBody = json.decode(response.body);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseBody['message'])));
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'username');
      await _storage.delete(key: 'user_type');
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unable to logout")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Logout'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _logout,
              child: Text('Logout ?'),
            ),
          ],
        ),
      ),
    );
  }
}
