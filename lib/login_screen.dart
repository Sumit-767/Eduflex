import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'register_page.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = FlutterSecureStorage(); // Create an instance of FlutterSecureStorage
  int trial = 0;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async
  {
    await Future.delayed(Duration(seconds: 2));

    final token = await _storage.read(key : 'auth_token');
    if (token != null && (trial  == 0))
      {
        final responce = await http.post(
          Uri.parse('http://192.168.31.28:8000/mobiletoken'),
          headers: {
            'Content-Type' : 'application/json',
          },
          body: json.encode({
            'mobiletoken' : token,
          })
        );

        if (responce.statusCode == 200)
          {
            final responceBody = json.decode(responce.body);
            final message = responceBody['message'];
            if (message == 'valid')
              {
                String pop = "Succesfull Auto Login";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pop)));
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
          }
        else if (responce.statusCode == 401)
        {
          final responceBody = json.decode(responce.body);
          final message = responceBody['message'];
          if (message == 'No token found')
          {
            String pop = "PLS login";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pop)));
            Navigator.pushReplacementNamed(context, '/');
          }
        }
        else if (responce.statusCode == 400)
            {
              final responceBody = json.decode(responce.body);
              final message = responceBody['message'];
              if (message == 'expired')
              {
                String pop = "PLS login";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pop)));
                Navigator.pushReplacementNamed(context, '/');
              }
            }
      }
    else
      {
        String pop = "Long Live Token Not Found";
        trial = trial +1;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pop)));
        Navigator.pushReplacementNamed(context, '/');
      }
  }


  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    final response = await http.post(
      Uri.parse('http://192.168.31.28:8000/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'userUsername': username,
        'userPwd': password,
        'interface': 'Mobileapp', // Specify the interface
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      final message = responseBody['message'];
      final token = responseBody['token'];

      if (token != null) {
        // Store the token securely
        await _storage.write(key: 'auth_token', value: token);
        print("Long-lived token stored securely.");
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      final responseBody = json.decode(response.body);
      final message = responseBody['message'] ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            //ElevatedButton(onPressed: _autoLogin, child: Text('Auto Login')),
            TextButton(
              onPressed: () {
                // Navigate to the registration page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text('Don\'t have an account? Register here'),
            ),
          ],
        ),
      ),
    );
  }
}
