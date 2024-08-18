import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:carousel_slider/carousel_slider.dart';


class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ProfilePage(),
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
              title: Text('Settings'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              title: Text('Goodies'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              title: Text('Logout'),
              onTap: () => _onItemTapped(4),
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
      body: Center(child: Text('Home Page')),
    );
  }
}


class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}



class _ProfilePageState extends State<ProfilePage> {
  PlatformFile? _selectedFile;
  final TextEditingController _descriptionController = TextEditingController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  List<Map<String, dynamic>> _userPosts = [];
  List<String> _hashtags = [];
  List<String> _selectedHashtags = [];

  @override
  void initState() {
    super.initState();
    _fetchUserPosts(); // Fetch posts when the page initializes
  }

  Future<void> _fetchUserPosts() async {
    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');
    final Uri url = Uri.parse('https://nice-genuinely-pug.ngrok-free.app/myprofile');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'Token': token,
        'interface': "Mobileapp",
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _userPosts = List<Map<String, dynamic>>.from(data['data']);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch posts')));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });

      // Send file to backend for text extraction and hashtags
      await _extractHashtagsFromPDF(_selectedFile!);
    }
  }

  Future<void> _extractHashtagsFromPDF(PlatformFile file) async {
    final username = await _storage.read(key: 'username');
    final token = await _storage.read(key: 'auth_token');

    if (username == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication error. Please log in again.')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file selected')),
      );
      return;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://nice-genuinely-pug.ngrok-free.app/extract-hashtags'),
      );

      request.fields['up_username'] = username;
      request.fields['Token'] = token;
      request.fields['interface'] = "Mobileapp";
      request.fields['filename'] = _selectedFile!.name;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _selectedFile!.path!,
          contentType: MediaType.parse(lookupMimeType(_selectedFile!.path!)!),
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final List<String> hashtags = List<String>.from(json.decode(responseBody));

        setState(() {
          _hashtags = hashtags;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch hashtags. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error communicating with server: $e')),
      );
    }
  }



  Future<void> _uploadFile(BuildContext context) async {
    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');

    if (_selectedFile == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file and enter a description')),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://nice-genuinely-pug.ngrok-free.app/upload'),
    );

    request.fields['Token'] = token!;
    request.fields['post_type'] = 'post';
    request.fields['post_desc'] = _descriptionController.text;
    request.fields['interface'] = 'Mobileapp';
    request.fields['up_username'] = username!;
    request.fields['filename'] = _selectedFile!.name;
    request.fields['hashtags'] = jsonEncode(_selectedHashtags); // Assign the comma-separated string

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        _selectedFile!.path!,
        contentType: MediaType.parse(lookupMimeType(_selectedFile!.path!)!),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploading...')));

    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload successful')));
      _fetchUserPosts(); // Refresh the posts after upload
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed')));
    }

    setState(() {
      _selectedFile = null;
      _descriptionController.clear();
      _selectedHashtags.clear(); // Clear selected hashtags after upload
    });

    Navigator.pop(context);
  }


  Future<void> _deletePost(String postID) async {
    final token = await _storage.read(key: 'auth_token');
    final Uri url = Uri.parse('https://nice-genuinely-pug.ngrok-free.app/deletePost'); // Replace with your API URL

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'Token': token,
        'postID': postID,
        'interface': 'Mobileapp',
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted successfully')));
      setState(() {
        _fetchUserPosts(); // Refresh the posts after deletion
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete post')));
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
                  child: SizedBox(
                    height: 200,
                    child: _selectedFile!.extension == 'pdf'
                        ? Icon(Icons.picture_as_pdf, size: 100) // Show PDF icon
                        : Image.file(
                      File(_selectedFile!.path!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (_hashtags.isNotEmpty)
                Container(
                  height: 50,
                  margin: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _hashtags.map((hashtag) {
                        final isSelected = _selectedHashtags.contains(hashtag);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(hashtag),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent,
                            backgroundColor: Colors.grey[200],
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedHashtags.add(hashtag);
                                } else {
                                  _selectedHashtags.remove(hashtag);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Post Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadFile(context);
                  },
                  child: Text('Upload'),
                ),
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
        title: Text('Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _userPosts.isEmpty
          ? Center(child: Text('No posts available'))
          : ListView.builder(
        itemCount: _userPosts.length,
        itemBuilder: (context, index) {
          final post = _userPosts[index];
          final List<dynamic> images = post['images'] ?? [];
          final List<dynamic> badges = post['credly_badges'] ?? []; // Assuming 'credly_badges' is the key

          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty) ...[
                  CarouselSlider.builder(
                    itemCount: images.length,
                    itemBuilder: (context, itemIndex, realIndex) {
                      return Image.network(
                        'https://nice-genuinely-pug.ngrok-free.app' + images[itemIndex],
                        fit: BoxFit.cover,
                      );
                    },
                    options: CarouselOptions(
                      height: 400.0,
                      aspectRatio: 16 / 9,
                      viewportFraction: 0.8,
                      initialPage: 0,
                      enableInfiniteScroll: false,
                      reverse: false,
                      autoPlay: false,
                      autoPlayInterval: Duration(seconds: 5),
                      autoPlayAnimationDuration: Duration(milliseconds: 800),
                      enlargeCenterPage: true,
                      scrollDirection: Axis.horizontal,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(post['post_desc'] ?? 'No Description'),
                ),
                if (badges.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Credly Badges:',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  ...badges.map((badge) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 5,
                      child: ListTile(
                        contentPadding: EdgeInsets.all(8.0),
                        title: Text(
                          badge['cert_name'] ?? 'No Certificate Name',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        subtitle: Text(
                          '${badge['firstname'] ?? ''} ${badge['lastname'] ?? ''}\n'
                              'Issued: ${badge['issued_date'] ?? 'No Issue Date'}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        leading: Image.network(
                          badge['badge_image'] ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )),
                ],
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deletePost(post['postID']),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showUploadModal(context);
        },
        child: Icon(Icons.upload_file),
        backgroundColor: Colors.blue,
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
      Uri.parse('https://nice-genuinely-pug.ngrok-free.app/changeprofile'),
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
        Uri.parse('https://nice-genuinely-pug.ngrok-free.app/logout'),
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
