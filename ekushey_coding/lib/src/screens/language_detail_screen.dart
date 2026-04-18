import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class LanguageDetailScreen extends StatefulWidget {
  const LanguageDetailScreen({super.key, required this.language});

  final LanguageMeta language;

  @override
  State<LanguageDetailScreen> createState() => _LanguageDetailScreenState();
}

class _LanguageDetailScreenState extends State<LanguageDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  List<TutorialItem> _tutorials = <TutorialItem>[];
  List<ExerciseItem> _exercises = <ExerciseItem>[];
  bool _loading = true;

  final Map<int, int> _answers = <int, int>{};
  bool _submittedQuiz = false;

  static const List<_QuizQuestion> _quiz = <_QuizQuestion>[
    _QuizQuestion(
      question: 'What keyword is commonly used for constant values?',
      options: <String>['var', 'let', 'const', 'finalize'],
      correctIndex: 2,
    ),
    _QuizQuestion(
      question: 'Which command prints output in most languages?',
      options: <String>[
        'echo()',
        'log()',
        'print()/console.log()',
        'writeLineForever()',
      ],
      correctIndex: 2,
    ),
    _QuizQuestion(
      question: 'What helps keep code maintainable?',
      options: <String>[
        'Long files only',
        'No naming conventions',
        'Reusable functions/modules',
        'No comments ever',
      ],
      correctIndex: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = context.read<AppState>();

    try {
      final tutorials = await appState.contentService.fetchTutorials(
        languageId: widget.language.id,
      );
      final exercises = await appState.contentService.fetchExercises(
        languageId: widget.language.id,
        perPage: 100,
      );

      if (!mounted) return;
      setState(() {
        _tutorials = tutorials;
        _exercises = exercises.items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tutorials = <TutorialItem>[];
        _exercises = <ExerciseItem>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int get _score {
    var score = 0;
    for (var i = 0; i < _quiz.length; i++) {
      if (_answers[i] == _quiz[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppState>().locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.language.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Tab>[
            Tab(text: AppStrings.getByLocale(locale, 'about_tab')),
            Tab(text: AppStrings.getByLocale(locale, 'tutorials_tab')),
            Tab(text: AppStrings.getByLocale(locale, 'exercises_tab')),
          ],
        ),
      ),
      body: GradientBackdrop(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _AboutTab(language: widget.language, locale: locale),
                    _TutorialsTab(tutorials: _tutorials, locale: locale),
                    _ExercisesTab(
                      exercises: _exercises,
                      locale: locale,
                      quiz: _quiz,
                      answers: _answers,
                      submittedQuiz: _submittedQuiz,
                      score: _score,
                      onSelectAnswer: (q, a) => setState(() => _answers[q] = a),
                      onSubmitQuiz: () => setState(() => _submittedQuiz = true),
                      onResetQuiz: () => setState(() {
                        _submittedQuiz = false;
                        _answers.clear();
                      }),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.language, required this.locale});

  final LanguageMeta language;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(language.description),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    Chip(
                      label: Text(
                        '${AppStrings.getByLocale(locale, 'version')}: ${language.version}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${AppStrings.getByLocale(locale, 'difficulty')}: ${language.difficulty}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SectionHeader(title: AppStrings.getByLocale(locale, 'key_features')),
        const SizedBox(height: 8),
        ...language.features.map(
          (f) => Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(f),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(title: AppStrings.getByLocale(locale, 'use_cases')),
        const SizedBox(height: 8),
        ...language.useCases.map(
          (u) => Card(
            child: ListTile(
              leading: const Icon(Icons.code_rounded),
              title: Text(u),
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorialsTab extends StatelessWidget {
  const _TutorialsTab({required this.tutorials, required this.locale});

  final List<TutorialItem> tutorials;
  final String locale;

  @override
  Widget build(BuildContext context) {
    if (tutorials.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          EmptyStateCard(
            title: 'No tutorials yet',
            subtitle: 'This language has no published tutorials right now.',
            icon: Icons.menu_book_rounded,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: tutorials
          .map(
            (t) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(t.title),
                subtitle: Text(
                  '${AppStrings.getByLocale(locale, 'lesson')} ${t.order}',
                ),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(t.content),
                        if ((t.codeExample ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF020617)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                t.codeExample!,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab({
    required this.exercises,
    required this.locale,
    required this.quiz,
    required this.answers,
    required this.submittedQuiz,
    required this.score,
    required this.onSelectAnswer,
    required this.onSubmitQuiz,
    required this.onResetQuiz,
  });

  final List<ExerciseItem> exercises;
  final String locale;
  final List<_QuizQuestion> quiz;
  final Map<int, int> answers;
  final bool submittedQuiz;
  final int score;
  final void Function(int, int) onSelectAnswer;
  final VoidCallback onSubmitQuiz;
  final VoidCallback onResetQuiz;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        if (exercises.isEmpty)
          const EmptyStateCard(
            title: 'No exercises yet',
            subtitle: 'Exercises for this language are not published yet.',
            icon: Icons.integration_instructions_outlined,
          )
        else
          ...exercises
              .take(5)
              .map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(item.titleByLocale(locale)),
                    subtitle: Text(
                      item.problemByLocale(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(item.difficulty),
                  ),
                ),
              ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.getByLocale(locale, 'quick_quiz'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(quiz.length, (index) {
                  final q = quiz[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${index + 1}. ${q.question}'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List<Widget>.generate(q.options.length, (
                            optIndex,
                          ) {
                            return ChoiceChip(
                              selected: answers[index] == optIndex,
                              label: Text(q.options[optIndex]),
                              onSelected: submittedQuiz
                                  ? null
                                  : (_) => onSelectAnswer(index, optIndex),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }),
                if (submittedQuiz)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Score: $score / ${quiz.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  children: <Widget>[
                    FilledButton(
                      onPressed: submittedQuiz ? null : onSubmitQuiz,
                      child: Text(
                        AppStrings.getByLocale(locale, 'check_answers'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onResetQuiz,
                      child: Text(AppStrings.getByLocale(locale, 'reset')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
}
