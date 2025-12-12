/// ===========================================================================
/// VIDEO SPLASH SCREEN
/// ===========================================================================
///
/// PURPOSE: Animated video splash screen displayed on app launch.
///          Plays splash.mov and navigates based on auth state.
///
/// KEY FEATURES:
///   - Video playback using video_player package
///   - Error fallback if video fails to load
///   - Auth-aware navigation after video completes
///
/// NAVIGATION:
///   - Logged in user → /main-menu
///   - No user → /landing
///
/// DEPENDENCIES:
///   - video_player: Video playback
///   - firebase_auth: Auth state check
/// ===========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';


class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/splash.mov')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      }).catchError((error) {
        debugPrint("Video player error: $error");
        // Fallback to main menu if video fails
        _navigateNext();
      })
      ..addListener(() {
        // When the video ends, move to the next screen
        if (_controller.value.isInitialized && 
            !_controller.value.isPlaying && 
            _controller.value.position >= _controller.value.duration) {
          _navigateNext();
        }
      });
  }

  void _navigateNext() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/main-menu');
    } else {
      Navigator.pushReplacementNamed(context, '/landing');
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
