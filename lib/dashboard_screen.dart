import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;


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

class HomePage extends StatefulWidget{
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final response = await http.get(
      Uri.parse('https://nice-genuinely-pug.ngrok-free.app/search-user-result?q=$query'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _searchResults = data.map((user) => user as Map<String, dynamic>).toList();
      });
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'EduFlex',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 16.0),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  _searchUsers(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: Colors.black38),
                  prefixIcon: Icon(Icons.search, color: Colors.black38),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: Colors.black38),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isSearching && _searchResults.isEmpty
          ? Center(child: Text('No results found'))
          : _isSearching
          ? ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return ListTile(
            title: Text('${user['firstname']} ${user['lastname']}'),
            subtitle: Text(user['username']),
            onTap: () {
              // Implement navigation to the user's profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(
                    username: user['username'],           // The user data
                  ),
                ),
              );

            },
          );
        },
      )
          : Center(child: Text('Home Page')), // Replace this with your original home page content
    );
  }
}

class UserProfilePage extends StatefulWidget {
  final String username;

  UserProfilePage({required this.username});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final Uri url = Uri.parse('https://nice-genuinely-pug.ngrok-free.app/profile?username=${widget.username}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch profile')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching profile: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.username}'),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(username: widget.username),
                ),
              );
            },
            icon: Icon(Icons.send, color: Colors.white),
            label: Text('Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Set button color to blue
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              textStyle: TextStyle(fontSize: 16.0), // Adjust font size if needed
            ),
          ),
          SizedBox(width: 10.0), // Add some padding on the right
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? Center(child: Text('No posts available'))
          : SingleChildScrollView(
        child: Column(
          children: _posts.map((post) {
            final List<dynamic> images = post['imagePaths'] ?? [];
            final List<dynamic> hashtags = post['hashtags'] ?? [];

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty) ...[
                    CarouselSlider(
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
                      items: images.map<Widget>((path) {
                        return Image.network(
                          'https://nice-genuinely-pug.ngrok-free.app/$path',
                          fit: BoxFit.cover,
                        );
                      }).toList(),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      post['post_desc'] ?? 'No Description',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  SizedBox(height: 16.0),
                  if (hashtags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8.0,
                      children: hashtags.map<Widget>((tag) {
                        return Chip(
                          label: Text('#$tag'),
                        );
                      }).toList(),
                    ),
                  ],
                  SizedBox(height: 16.0),
                  Row(
                    children: [
                      Icon(Icons.thumb_up),
                      SizedBox(width: 8.0),
                      Text('${post['post_likes'] ?? 0} Likes'),
                    ],
                  ),
                  SizedBox(height: 16.0),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}



class ChatScreen extends StatefulWidget {
  final String username;

  const ChatScreen({Key? key, required this.username}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _messages = [];
  late IO.Socket _socket;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io('https://nice-genuinely-pug.ngrok-free.app/', IO.OptionBuilder()
        .setTransports(['websocket']) // for Flutter or Dart VM
        .build());

    _socket.onConnect((_) async{
      final token = await _storage.read(key: 'auth_token');
      _socket.emit('authenticate', {
        'Token': token,
        'interface': 'Mobileapp',
      });
    });

    _socket.on('receive_message', (data) {
      setState(() {
        _messages.add('${data['sender']}: ${data['message']}');
      });
    });

    _socket.onDisconnect((_) {
      print('Disconnected from server');
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _socket.emit('private_message', {
        'sender': 'your_username',
        'receiver': widget.username,
        'message': _controller.text,
        'token': 'your_csrf_token',
        'interface': 'Webapp',
      });
      setState(() {
        _messages.add('You: ${_controller.text}');
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.username}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous screen
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
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
  Map<String, dynamic>? _userBio;
  List<Map<String, dynamic>> _userPosts = [];
  List<String> _hashtags = [];
  List<String> _selectedHashtags = [];
  bool _isLoading = true;
  final String userpicurl = '';

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
        _userBio = (data['userbio']as List).isNotEmpty ? data['userbio'][0] : null;
        _userPosts = List<Map<String, dynamic>>.from(data['data']);
        String userpicurl = 'https://nice-genuinely-pug.ngrok-free.app/uploads/${_userBio!['username']}/profile/profile.jpg';
        _isLoading = false;
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
      _isLoading = true;
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
        _isLoading = true;
        _fetchUserPosts();
        // Refresh the posts after deletion
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserProfile(), // This method displays the user bio
            const SizedBox(height: 20), // Add some spacing between the bio and posts
            _userPosts.isEmpty
                ? Center(child: Text('No posts available'))
                : ListView.builder(
              physics: NeverScrollableScrollPhysics(), // Ensure the ListView scrolls with the entire page
              shrinkWrap: true,
              itemCount: _userPosts.length,
              itemBuilder: (context, index) {
                final post = _userPosts[index];
                final List<dynamic> images = post['images'] ?? [];
                final List<dynamic> badges = post['credly_badges'] ?? [];

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
                                style: Theme.of(context).textTheme.bodyLarge,
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
          ],
        ),
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

  // Widget to display user profile
  Widget _buildUserProfile() {
    if (_userBio == null) {
      return Center(child: Text('No profile information available.'));
    }

    // Construct the profile image URL based on the username
    final String profileImageUrl =
        'https://nice-genuinely-pug.ngrok-free.app/uploads/${_userBio!['username']}/profile/profile.jpg';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile picture
              CircleAvatar(
                radius: 40, // Adjust the size as needed
                backgroundImage: NetworkImage(profileImageUrl),
                onBackgroundImageError: (_, __) {
                  print('Error loading profile image');
                },
                backgroundColor: Colors.grey[300], // Placeholder color
              ),
              SizedBox(width: 20), // Add some spacing between the image and name
              // Name
              Expanded(
                child: Text(
                  '${_userBio!['firstname']} ${_userBio!['lastname']}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: 20), // Add some spacing after the row
          Text(
            'Email: ${_userBio!['email']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 5),
          Text(
            'Phone: ${_userBio!['phone_number']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 5),
          Text(
            'Bio: ${_userBio!['bio']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 5),
          Text(
            'College: ${_userBio!['college']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 5),
          Text(
            'CGPA: ${_userBio!['cgpa'].toString()}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
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
  final _githubController = TextEditingController();
  final _websiteController = TextEditingController();
  final _bioController = TextEditingController();
  final _collegeController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _hobbyController = TextEditingController();
  final _storage = FlutterSecureStorage();

  File? _selectedImage;
  DateTime? _selectedDateOfBirth;
  String? _selectedAcademicYear;
  String? _selectedSemester;
  String? _profilePictureUrl;

  // Academic year options
  final List<String> _academicYears = [
    'First Year',
    'Second Year',
    'Third Year',
    'Final Year'
  ];

  // Semester mapping based on the academic year
  Map<String, List<String>> _semesters = {
    'First Year': ['Sem 1', 'Sem 2'],
    'Second Year': ['Sem 3', 'Sem 4'],
    'Third Year': ['Sem 5', 'Sem 6'],
    'Final Year': ['Sem 7', 'Sem 8'],
  };

  Future<void> _updateProfile() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final phone = _phoneController.text;
    final github = _githubController.text;
    final website = _websiteController.text;
    final bio = _bioController.text;
    final college = _collegeController.text;
    final cgpa = _cgpaController.text;
    final hobby = _hobbyController.text;
    final dob = _selectedDateOfBirth?.toIso8601String(); // Convert DateTime to String
    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');

    var uri = Uri.parse('https://nice-genuinely-pug.ngrok-free.app/changeprofile');
    var request = http.MultipartRequest('POST', uri);

    // Add other fields to the request
    request.fields['Token'] = token!;
    request.fields['username'] = username!;
    request.fields['changeemail'] = email;
    request.fields['changepwd'] = password;
    request.fields['changephoneno'] = phone;
    request.fields['dob'] = dob ?? '';
    request.fields['github'] = github;
    request.fields['website'] = website;
    request.fields['bio'] = bio;
    request.fields['college'] = college;
    request.fields['academicyear'] = _selectedAcademicYear ?? '';
    request.fields['semester'] = _selectedSemester ?? '';
    request.fields['cgpa'] = cgpa;
    request.fields['hobby'] = hobby;
    request.fields['interface'] = 'Mobileapp';

    // Add the image file if selected
    if (_selectedImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Key for the file (should match the server-side expectation)
          _selectedImage!.path,
          contentType: MediaType.parse(lookupMimeType(_selectedImage!.path)!),
        ),
      );
    }

    try {
      // Send the request to the server
      var response = await request.send();

      // Check the response
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update successful!')));
        await _storage.delete(key: 'auth_token');
        Navigator.pushReplacementNamed(context, '/');
      } else {
        var responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${responseBody}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // Default date
      firstDate: DateTime(1900), // Earliest selectable date
      lastDate: DateTime.now(), // Latest selectable date
    );
    if (pickedDate != null && pickedDate != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = pickedDate;
      });
    }
  }

  // Function to select an image
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');

    final uri = Uri.parse('https://nice-genuinely-pug.ngrok-free.app/getUserProfile');

    final response = await http.post(
      uri,
      body: {
        'Token': token ?? '',       // Send the token in the body
        'username': username ?? '',
        'interface' : "Mobileapp"// Send the username in the body
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone_number'] ?? '';
        _githubController.text = data['github'] ?? '';
        _websiteController.text = data['website'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _collegeController.text = data['college'] ?? '';
        _cgpaController.text = data['cgpa']?.toString() ?? '';
        _hobbyController.text = data['hobby'] ?? '';
        _selectedAcademicYear = data['academic_year'];
        _selectedSemester = data['semester'];
        _passwordController.text = data['password'];
        if (data['dob'] != null) {
          _selectedDateOfBirth = DateTime.parse(data['dob']);
        }
        _profilePictureUrl = 'https://nice-genuinely-pug.ngrok-free.app/uploads/$username/profile/profile.jpg';
      });
    } else {
      // Handle the error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile')));
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
      body: SingleChildScrollView(
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
            // Date of Birth selection
            ListTile(
              title: Text(_selectedDateOfBirth == null
                  ? 'Select Date of Birth'
                  : 'Date of Birth: ${_selectedDateOfBirth!.toLocal().toString().split(' ')[0]}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDateOfBirth(context),
            ),
            TextField(
              controller: _githubController,
              decoration: InputDecoration(labelText: 'GitHub Link'),
            ),
            TextField(
              controller: _websiteController,
              decoration: InputDecoration(labelText: 'Website Link'),
            ),
            TextField(
              controller: _bioController,
              decoration: InputDecoration(labelText: 'Bio'),
            ),
            TextField(
              controller: _collegeController,
              decoration: InputDecoration(labelText: 'College Name'),
            ),
            // Academic Year Dropdown
            DropdownButtonFormField<String>(
              value: _selectedAcademicYear,
              hint: Text('Select Academic Year'),
              onChanged: (newValue) {
                setState(() {
                  _selectedAcademicYear = newValue;
                  _selectedSemester = null; // Reset semester when year changes
                });
              },
              items: _academicYears.map((year) {
                return DropdownMenuItem(
                  child: Text(year),
                  value: year,
                );
              }).toList(),
            ),
            // Semester Dropdown based on selected Academic Year
            if (_selectedAcademicYear != null)
              DropdownButtonFormField<String>(
                value: _selectedSemester,
                hint: Text('Select Semester'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedSemester = newValue;
                  });
                },
                items: _semesters[_selectedAcademicYear]!.map((semester) {
                  return DropdownMenuItem(
                    child: Text(semester),
                    value: semester,
                  );
                }).toList(),
              ),
            TextField(
              controller: _cgpaController,
              decoration: InputDecoration(labelText: 'CGPA'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _hobbyController,
              decoration: InputDecoration(labelText: 'Hobby'),
            ),
            SizedBox(height: 20),
            _profilePictureUrl != null && _selectedImage == null
                ? CircleAvatar(
              radius: 75, // Adjust the size as needed
              backgroundImage: NetworkImage(_profilePictureUrl!),
            )
                : _selectedImage != null
                ? Image.file(_selectedImage!, height: 150)
                : Text('No image selected.'),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Profile Photo'),
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
