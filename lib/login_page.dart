import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                // IMPORTANT: You'll need to add a background image.
                // 1. Create an 'assets/images/' folder in your project's root.
                // 2. Place an image (e.g., 'background.jpg') in 'assets/images/'.
                // 3. Declare the assets folder in your pubspec.yaml file:
                //    flutter:
                //      assets:
                //        - assets/images/
                image: AssetImage('assets/images/background.jpg'), // Update if your image name is different
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Login Form
          Center(
            child: SingleChildScrollView( // Ensures content is scrollable if keyboard appears
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // LOGIN Title
                  const Text(
                    'LOGIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 50.0),

                  // Email TextField
                  _buildTextField(
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    obscureText: false,
                  ),
                  const SizedBox(height: 20.0),

                  // Password TextField
                  _buildTextField(
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 10.0),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Placeholder for forgot password functionality
                        print('Forgot Password Tapped');
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.white70, fontSize: 14.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30.0),

                  // LOGIN Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A5AE0), // A purple shade similar to video
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      onPressed: () {
                        // Placeholder for login functionality
                        print('Login Tapped');
                      },
                      child: const Text(
                        'LOGIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40.0), // Spacing before "Sign up"

                  // Don't have an account? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.white70, fontSize: 15.0),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Placeholder for sign up navigation/functionality
                          print('Sign up Tapped');
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Color(0xFF6A5AE0), // Matching button color
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build styled TextFields
  Widget _buildTextField({
    required String hintText,
    required IconData icon,
    required bool obscureText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0), // Reduced padding for icon space
      decoration: BoxDecoration(
        color: Colors.grey[200]?.withOpacity(0.8), // Light grey, slightly transparent
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: TextField(
        obscureText: obscureText,
        style: const TextStyle(color: Colors.black87, fontSize: 16.0),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0), // Adjust vertical padding
          icon: Padding( // Add padding around the icon
            padding: const EdgeInsets.only(left: 10.0),
            child: Icon(icon, color: Colors.grey[700]),
          ),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16.0),
          border: InputBorder.none, // Remove the default border
        ),
      ),
    );
  }
}