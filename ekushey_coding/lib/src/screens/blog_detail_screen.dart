import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class BlogDetailScreen extends StatelessWidget {
  const BlogDetailScreen({super.key, required this.post, required this.locale});

  final BlogPost post;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getByLocale(locale, 'blog_details')),
      ),
      body: GradientBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(label: Text(post.categoryByLocale(locale))),
                          Chip(label: Text(post.readTimeByLocale(locale))),
                          Chip(
                            label: Text(
                              '${post.views} ${AppStrings.getByLocale(locale, 'views')}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post.titleByLocale(locale),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(post.authorByLocale(locale)),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (post.publishedAt ?? post.createdAt)
                                    ?.toLocal()
                                    .toString()
                                    .split(' ')
                                    .first ??
                                'N/A',
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        post.contentByLocale(locale),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: post.tags
                            .map((tag) => Chip(label: Text('#$tag')))
                            .toList(),
                      ),
                    ],
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
