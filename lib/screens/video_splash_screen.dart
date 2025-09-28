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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    // Option 1: Auto navigate after duration (e.g., 3 sec)
    _timer = Timer(const Duration(seconds: 3), _navigateToNext);

    // Option 2: Or listen to video end
    // _controller.addListener(() {
    //   if (_controller.value.position >= _controller.value.duration) {
    //     _navigateToNext();
    //   }
    // });
  }

  void _navigateToNext() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main-menu');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
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
