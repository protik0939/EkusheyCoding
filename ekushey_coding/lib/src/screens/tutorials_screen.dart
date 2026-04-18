import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/languages.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'tutorial_detail_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.getByLocale(appState.locale, 'failed_load_tutorials')}: $e',
          ),
        ),
      );
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final glassTop = isDark
        ? const Color(0xFF0D203F).withValues(alpha: 0.72)
        : const Color(0xFFF3F7FF).withValues(alpha: 0.88);
    final glassBottom = isDark
        ? const Color(0xFF08152C).withValues(alpha: 0.62)
        : const Color(0xFFDCEAFF).withValues(alpha: 0.70);
    final glassStroke = isDark
        ? const Color(0xFF3B5F92).withValues(alpha: 0.48)
        : const Color(0xFF9FBDE5).withValues(alpha: 0.72);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.42)
        : const Color(0x14355C8A);
    final sheenColor = isDark
        ? const Color(0xFF8FB7FF).withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.42);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[glassTop, glassBottom],
              ),
              border: Border.all(color: glassStroke, width: 1),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -42,
                  right: -26,
                  child: IgnorePointer(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[sheenColor, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    initiallyExpanded: tutorials.length < 4,
                    title: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${tutorials.length} $lessonsLabel'),
                    ),
                    trailing: IconButton(
                      onPressed: onHeaderTap,
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                    children: tutorials
                        .map(
                          (TutorialItem tutorial) => ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: isDark ? 0.24 : 0.14,
                              ),
                              foregroundColor: colorScheme.primary,
                              child: Text(
                                '${tutorial.order}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(tutorial.getTitleByLocale(locale)),
                            subtitle: Text(
                              tutorial.getContentByLocale(locale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      TutorialDetailScreen(
                                        tutorial: tutorial,
                                        locale: locale,
                                      ),
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
