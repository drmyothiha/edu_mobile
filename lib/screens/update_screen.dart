import 'package:flutter/material.dart';
import '../widgets/update_dialog.dart';

/// Full screen dedicated view for app updates.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Software Updates'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: UpdateDialog(autoCheckOnOpen: true),
        ),
      ),
    );
  }
}
