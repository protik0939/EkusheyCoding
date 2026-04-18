import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/strings.dart';
import '../widgets/common.dart';

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  static const List<Map<String, String>> _certificates = <Map<String, String>>[
    {
      'title': 'Frontend Mastery Certificate',
      'track': 'HTML, CSS, JavaScript, React',
      'level': 'Intermediate',
      'duration': '8 weeks',
    },
    {
      'title': 'Backend API Developer Certificate',
      'track': 'Node.js, Express, REST, SQL',
      'level': 'Advanced',
      'duration': '10 weeks',
    },
    {
      'title': 'Problem Solving Certificate',
      'track': 'Algorithms, Data Structures, Complexity',
      'level': 'Intermediate',
      'duration': '6 weeks',
    },
    {
      'title': 'Full Stack Foundations Certificate',
      'track': 'Frontend + Backend + Deployment',
      'level': 'Beginner',
      'duration': '12 weeks',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final locale = appState.locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getByLocale(locale, 'certificates_title')),
      ),
      body: GradientBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              const SectionHeader(
                title: 'Certification Paths',
                subtitle:
                    'Validate your skills through structured learning tracks.',
              ),
              const SizedBox(height: 12),
              ..._certificates.map(
                (c) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          c['title']!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(c['track']!),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            Chip(label: Text('Level: ${c['level']}')),
                            Chip(label: Text('Duration: ${c['duration']}')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () {},
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: Text(AppStrings.getByLocale(locale, 'enroll')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
