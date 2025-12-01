import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isPhoneNumber(input)) {
        await _verifyPhoneNumber(input);
      } else {
        if (password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter your password")),
          );
          return;
        }
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
        
        final user = userCredential.user;
        if (user != null) {
           try {
             final data = await Supabase.instance.client
                 .from('user_profiles')
                 .select()
                 .eq('user_id', user.uid)
                 .maybeSingle();
             
             if (data != null) {
               final prefs = await SharedPreferences.getInstance();
               if (data['full_name'] != null) {
                 await prefs.setString('user_full_name', data['full_name']);
               }
               if (data['avatar_url'] != null) {
                 await prefs.setString('user_avatar_url', data['avatar_url']);
               }
             }
           } catch (e) {
             debugPrint("Error fetching profile on login: $e");
           }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/location-permission');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Save to Supabase
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.uid,
          'email': user.email,
          'full_name': user.displayName,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (user.displayName != null) {
          await prefs.setString('user_full_name', user.displayName!);
        }
        // For Google Sign-In, we might want to use user.photoURL if Supabase doesn't have one yet,
        // but for consistency let's fetch from Supabase or just rely on what we have.
        // If we just upserted, we might not have the avatar_url in the local variable if it was existing.
        // Let's try to fetch the latest profile to be sure, or just set it if we had one.
        // Actually, Google user has photoURL. Let's save that if we want to use it as default.
        if (user.photoURL != null) {
           await prefs.setString('user_avatar_url', user.photoURL!);
           // Also update Supabase if it's missing there? 
           // The upsert above didn't include avatar_url. 
           // Let's leave it for now to avoid overwriting a custom one.
        }
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/location-permission');
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed: $e")),
        );
      }
    }
  }

  bool _isPhoneNumber(String input) {
    // Simple check: if it contains only digits (and maybe a +), treat as phone
    final clean = input.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^\+?[0-9]+$').hasMatch(clean);
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/location-permission');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Phone Auth Failed: ${e.message}")),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _showOtpDialog(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showOtpDialog(String verificationId) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter OTP"),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter 6-digit code"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = otpController.text.trim();
              if (code.length < 6) return;

              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: code,
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushReplacementNamed(context, '/location-permission');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid OTP")),
                );
              }
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  Future<void> _signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/location-permission');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Guest login failed: $e")),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email to receive a password reset link."),
            const SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password reset link sent!")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to send reset link")),
                  );
                }
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colors from design
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE1EFEF);
    const Color limeGreen = Color(0xFF9FE870); // Approximate lime green
    const Color inputFill = Color(0xFFE1EFEF);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Background Image and Back Button
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Image.asset(
                    'assets/Background.png',
                    fit: BoxFit.fill,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4C4C4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20, color: primaryDark),
                    ),
                  ),
                ),
              ],
            ),

            // Body Content
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 0),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Login to your account",
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Form Container
                  Container(
                    width: MediaQuery.of(context).size.width * 0.92,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryDark,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Email / Phone No,", Colors.white),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hint: "Enter your email or phone no.",
                          fillColor: inputFill,
                          textColor: primaryDark,
                        ),
                        const SizedBox(height: 20),

                        _buildLabel("Password", Colors.white),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "Enter your password",
                          fillColor: inputFill,
                          textColor: primaryDark,
                          isPassword: true,
                          isVisible: _isPasswordVisible,
                          onVisibilityChanged: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Radio<bool>(
                                    value: true,
                                    groupValue: _rememberMe,
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = !_rememberMe;
                                      });
                                    },
                                    activeColor: Colors.white,
                                    fillColor: MaterialStateProperty.resolveWith((states) => Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Remember Me",
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _forgotPassword,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: limeGreen,
                              foregroundColor: primaryDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: primaryDark,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OR Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Text(
                                "OR",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              _googleSignIn();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inputFill,
                              foregroundColor: primaryDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Logo
                                Image.asset(
                                  'assets/toppng.com-google-g-logo-icon-480x480.png',
                                  height: 24,
                                  width: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF597872),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Guest Login
                        Center(
                          child: TextButton(
                            onPressed: _signInAnonymously,
                            child: const Text(
                              "Continue as Guest",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/registration');
                              },
                              child: Text(
                                "Register",
                                style: TextStyle(
                                  color: limeGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: limeGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required Color fillColor,
    required Color textColor,
    TextEditingController? controller,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor, width: 1.5),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off : Icons.visibility,
                  color: textColor.withOpacity(0.6),
                ),
                onPressed: onVisibilityChanged,
              )
            : null,
      ),
    );
  }
}
