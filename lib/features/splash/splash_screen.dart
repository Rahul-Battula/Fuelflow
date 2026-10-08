import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // Never let the splash trap the user: navigate after 6s no matter what
    // happens with the video (missing asset, decode failure, stalled playback).
    _fallbackTimer = Timer(const Duration(seconds: 6), _goNext);

    _controller = VideoPlayerController.asset('assets/videos/FuelFlow.mp4');
    _controller.addListener(_checkVideoEnd);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((_) {
      // Asset missing or unsupported — skip straight to the app.
      _goNext();
    });
  }

  void _checkVideoEnd() {
    if (_navigated) return;
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated) return;
    _navigated = true;
    _fallbackTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
child: _controller.value.isInitialized
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}