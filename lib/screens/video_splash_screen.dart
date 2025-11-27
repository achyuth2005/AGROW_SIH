import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
        Navigator.pushReplacementNamed(context, '/landing');
      })
      ..addListener(() {
        // When the video ends, move to the next screen
        if (_controller.value.isInitialized && 
            !_controller.value.isPlaying && 
            _controller.value.position >= _controller.value.duration) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      });
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
