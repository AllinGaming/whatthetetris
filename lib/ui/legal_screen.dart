import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.analytics, this.initialTab = 0});

  final AnalyticsService analytics;
  final int initialTab;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.analytics.screenViewed('legal'));
    unawaited(widget.analytics.featureSelected('legal'));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialTab.clamp(0, 1),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Terms'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Privacy'),
            Tab(text: 'Terms'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _LegalDocument(assetPath: 'PRIVACY.md'),
          _LegalDocument(assetPath: 'TERMS.md'),
        ],
      ),
    ),
  );
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: rootBundle.loadString(assetPath),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasData) {
        return const Center(child: Text('This document could not be loaded.'));
      }
      final text = snapshot.data!
          .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
          .replaceAll('**', '');
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SelectableText(
                text,
                style: const TextStyle(height: 1.55, color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    },
  );
}
