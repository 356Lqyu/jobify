import 'package:flutter/material.dart';

class SocialFeed extends StatefulWidget {
  const SocialFeed({super.key});

  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),

      ),
    );
  }
}

