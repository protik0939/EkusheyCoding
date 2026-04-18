import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/languages.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key, required this.onOpenLanguage});

  final ValueChanged<LanguageMeta> onOpenLanguage;

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  String _selectedLanguage = 'all';
  List<TutorialItem> _tutorials = <TutorialItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTutorials();
  }

  Future<void> _loadTutorials() async {
    setState(() => _loading = true);

    final appState = context.read<AppState>();
    try {
      final result = await appState.contentService.fetchTutorials(
        languageId: _selectedLanguage == 'all' ? null : _selectedLanguage,
        publishedOnly: true,
      );
      if (!mounted) return;
      setState(() => _tutorials = result);
    } catch (e) {
      if (!mounted) return;
      final locale = context.read<AppState>().locale;
      final errorMsg = AppStrings.getByLocale(
        appState.locale,
        'failed_load_tutorials',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorMsg: $e')));
      setState(() => _tutorials = <TutorialItem>[]);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final grouped = <String, List<TutorialItem>>{};
        for (final t in _tutorials) {
          grouped.putIfAbsent(t.languageId, () => <TutorialItem>[]).add(t);
        }

        return GradientBackdrop(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadTutorials,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  SectionHeader(
                    title: AppStrings.getByLocale(
                      appState.locale,
                      'page_tutorials',
                    ),
                    subtitle: AppStrings.getByLocale(
                      appState.locale,
                      'tutorials_subtitle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kLanguages.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final id = index == 0
                            ? 'all'
                            : kLanguages[index - 1].id;
                        final name = index == 0
                            ? AppStrings.getByLocale(
                                appState.locale,
                                'filter_all',
                              )
                            : kLanguages[index - 1].getLocalizedName(
                                appState.locale,
                              );
                        return ChoiceChip(
                          selected: _selectedLanguage == id,
                          label: Text(name),
                          onSelected: (_) {
                            setState(() => _selectedLanguage = id);
                            _loadTutorials();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_tutorials.isEmpty)
                    EmptyStateCard(
                      title: AppStrings.getByLocale(
                        appState.locale,
                        'empty_tutorials_title',
                      ),
                      subtitle: AppStrings.getByLocale(
                        appState.locale,
                        'empty_tutorials_subtitle',
                      ),
                      icon: Icons.menu_book_rounded,
                    )
                  else
                    ...grouped.entries.map((entry) {
                      LanguageMeta? language;
                      for (final l in kLanguages) {
                        if (l.id == entry.key) {
                          language = l;
                          break;
                        }
                      }
                      final title = language != null
                          ? language.getLocalizedName(appState.locale)
                          : entry.key;
                      return _TutorialGroupCard(
                        title: title,
                        tutorials: entry.value,
                        locale: appState.locale,
                        onHeaderTap: () {
                          if (language != null) {
                            widget.onOpenLanguage(language);
                          }
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TutorialGroupCard extends StatelessWidget {
  const _TutorialGroupCard({
    required this.title,
    required this.tutorials,
    required this.locale,
    required this.onHeaderTap,
  });

  final String title;
  final List<TutorialItem> tutorials;
  final String locale;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final lessonsLabel = AppStrings.getByLocale(locale, 'lessons_count');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: tutorials.length < 4,
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${tutorials.length} $lessonsLabel'),
        trailing: IconButton(
          onPressed: onHeaderTap,
          icon: const Icon(Icons.open_in_new_rounded),
        ),
        children: tutorials
            .map(
              (TutorialItem tutorial) => ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${tutorial.order}'),
                ),
                title: Text(tutorial.title),
                subtitle: Text(
                  tutorial.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
