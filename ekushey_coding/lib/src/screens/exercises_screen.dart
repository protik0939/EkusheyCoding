import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/strings.dart';
import '../data/languages.dart';
import '../models.dart';
import '../widgets/common.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.onOpenLanguage});

  final ValueChanged<LanguageMeta> onOpenLanguage;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedDifficulty = 'all';
  String _selectedLanguage = 'all';
  List<ExerciseItem> _items = <ExerciseItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = context.read<AppState>();

    try {
      final data = await appState.contentService.fetchExercises(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        difficulty: _selectedDifficulty,
        languageId: _selectedLanguage,
      );
      if (!mounted) return;
      setState(() => _items = data.items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.getByLocale(context.read<AppState>().locale, 'failed_load_exercises')}: $e',
          ),
        ),
      );
      setState(() => _items = <ExerciseItem>[]);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppState>().locale;

    return GradientBackdrop(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              SectionHeader(
                title: AppStrings.getByLocale(
                  context.read<AppState>().locale,
                  'page_exercises',
                ),
                subtitle: AppStrings.getByLocale(
                  context.read<AppState>().locale,
                  'exercises_subtitle',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: AppStrings.getByLocale(
                    context.read<AppState>().locale,
                    'exercises_subtitle',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String>(
                          value: _selectedDifficulty,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Beginner',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_beginner',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Intermediate',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_intermediate',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Advanced',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_advanced',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'easy',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_easy',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_medium',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'hard',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'difficulty_hard',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(
                              () => _selectedDifficulty = value ?? 'all',
                            );
                            _load();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                AppStrings.getByLocale(
                                  context.read<AppState>().locale,
                                  'all_languages',
                                ),
                              ),
                            ),
                            ...kLanguages.map(
                              (lang) => DropdownMenuItem(
                                value: lang.id,
                                child: Text(lang.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedLanguage = value ?? 'all');
                            _load();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_items.isEmpty)
                const EmptyStateCard(
                  title: 'No exercises found',
                  subtitle: 'Try changing filters or search terms.',
                  icon: Icons.code_off_rounded,
                )
              else
                ..._items.map(
                  (ExerciseItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExerciseCard(
                      item: item,
                      locale: locale,
                      onOpenLanguage: () {
                        LanguageMeta? language;
                        for (final lang in kLanguages) {
                          if (lang.id == item.languageId) {
                            language = lang;
                            break;
                          }
                        }
                        if (language != null) {
                          widget.onOpenLanguage(language);
                        }
                      },
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

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.item,
    required this.locale,
    required this.onOpenLanguage,
  });

  final ExerciseItem item;
  final String locale;
  final VoidCallback onOpenLanguage;

  Color _difficultyColor(BuildContext context, String value) {
    final v = value.toLowerCase();
    if (v.contains('beginner') || v == 'easy') return Colors.green;
    if (v.contains('intermediate') || v == 'medium') return Colors.orange;
    if (v.contains('advanced') || v == 'hard') return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(context, item.difficulty);

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          item.titleByLocale(locale),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.difficultyByLocale(locale),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text('Views ${item.views}'),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if ((item.languageName ?? '').isNotEmpty)
                  InkWell(
                    onTap: onOpenLanguage,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Language: ${item.languageName}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                _InfoBlock(
                  title: 'Problem',
                  text: item.problemByLocale(locale),
                ),
                _InfoBlock(title: 'Input', text: item.inputByLocale(locale)),
                _InfoBlock(title: 'Output', text: item.outputByLocale(locale)),
                _InfoBlock(
                  title: 'Sample Input',
                  text: item.sampleInputByLocale(locale),
                ),
                _InfoBlock(
                  title: 'Sample Output',
                  text: item.sampleOutputByLocale(locale),
                ),
                if ((item.starterCode ?? '').isNotEmpty)
                  _CodeBlock(title: 'Starter Code', code: item.starterCode!),
                if ((item.solutionCode ?? '').isNotEmpty)
                  _CodeBlock(title: 'Solution Code', code: item.solutionCode!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(text),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.title, required this.code});

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF020617)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
