import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class TutorialDetailScreen extends StatefulWidget {
  const TutorialDetailScreen({
    super.key,
    required this.tutorial,
    required this.locale,
  });

  final TutorialItem tutorial;
  final String locale;

  @override
  State<TutorialDetailScreen> createState() => _TutorialDetailScreenState();
}

class _TutorialDetailScreenState extends State<TutorialDetailScreen> {
  late String _contentLocale;

  @override
  void initState() {
    super.initState();
    _contentLocale = widget.locale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tutorial.getTitleByLocale(_contentLocale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: SegmentedButton<String>(
                selected: <String>{_contentLocale},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _contentLocale = newSelection.first;
                  });
                },
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'en',
                    label: Text(
                      AppStrings.getByLocale(widget.locale, 'english'),
                    ),
                  ),
                  ButtonSegment<String>(
                    value: 'bn',
                    label: Text(
                      AppStrings.getByLocale(widget.locale, 'bangla'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                      // Header with lesson number and language
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(
                            label: Text(
                              '${AppStrings.getByLocale(widget.locale, 'lessons_count')} ${widget.tutorial.order}',
                            ),
                            avatar: CircleAvatar(
                              child: Text('${widget.tutorial.order}'),
                            ),
                          ),
                          if (widget.tutorial.languageId.isNotEmpty)
                            Chip(
                              label: Text(
                                widget.tutorial.languageId.toUpperCase(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        widget.tutorial.getTitleByLocale(_contentLocale),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),

                      // Content/Description
                      Text(
                        widget.tutorial.getContentByLocale(_contentLocale),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),

                      // Code Example Section (if available)
                      if (widget.tutorial.codeExample != null &&
                          widget.tutorial.codeExample!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.getByLocale(widget.locale, 'code_example'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              widget.tutorial.codeExample!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Meta Information
                      Text(
                        AppStrings.getByLocale(widget.locale, 'details'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _buildMetaInfo(context),
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

  Widget _buildMetaInfo(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildMetaRow(
          context,
          Icons.book_outlined,
          AppStrings.getByLocale(widget.locale, 'language_label'),
          widget.tutorial.languageId.toUpperCase(),
        ),
        const SizedBox(height: 8),
        _buildMetaRow(
          context,
          Icons.format_list_numbered,
          AppStrings.getByLocale(widget.locale, 'lesson_number'),
          '${widget.tutorial.order}',
        ),
        const SizedBox(height: 8),
        _buildMetaRow(
          context,
          Icons.check_circle_outline,
          AppStrings.getByLocale(widget.locale, 'status'),
          widget.tutorial.isPublished
              ? AppStrings.getByLocale(widget.locale, 'status_published')
              : AppStrings.getByLocale(widget.locale, 'status_draft'),
        ),
      ],
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
