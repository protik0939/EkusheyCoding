import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/languages.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenLanguage,
    required this.onOpenCertificates,
  });

  final ValueChanged<LanguageMeta> onOpenLanguage;
  final VoidCallback onOpenCertificates;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 1200
            ? 5
            : width >= 900
            ? 4
            : width >= 700
            ? 3
            : 2;

        return GradientBackdrop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroCard(
                    onOpenCertificates: onOpenCertificates,
                    locale: appState.locale,
                  ),
                  const SizedBox(height: 20),
                  _StatsRow(locale: appState.locale),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: AppStrings.getByLocale(
                      appState.locale,
                      'section_languages',
                    ),
                    subtitle: AppStrings.getByLocale(
                      appState.locale,
                      'section_languages_subtitle',
                    ),
                    trailing: TextButton(
                      onPressed: onOpenCertificates,
                      child: Text(
                        AppStrings.getByLocale(
                          appState.locale,
                          'btn_certificates',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: kLanguages.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final language = kLanguages[index];
                      return _LanguageCard(
                        language: language,
                        locale: appState.locale,
                        onTap: () => onOpenLanguage(language),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: AppStrings.getByLocale(
                      appState.locale,
                      'section_why',
                    ),
                    subtitle: AppStrings.getByLocale(
                      appState.locale,
                      'section_why_subtitle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _FeatureChip(
                        icon: Icons.bolt_rounded,
                        title: AppStrings.getByLocale(
                          appState.locale,
                          'feature_hands_on',
                        ),
                      ),
                      _FeatureChip(
                        icon: Icons.language_rounded,
                        title: AppStrings.getByLocale(
                          appState.locale,
                          'feature_bilingual',
                        ),
                      ),
                      _FeatureChip(
                        icon: Icons.school_rounded,
                        title: AppStrings.getByLocale(
                          appState.locale,
                          'feature_tutorial_first',
                        ),
                      ),
                      _FeatureChip(
                        icon: Icons.dashboard_customize_rounded,
                        title: AppStrings.getByLocale(
                          appState.locale,
                          'feature_admin',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onOpenCertificates, required this.locale});

  final VoidCallback onOpenCertificates;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppStrings.getByLocale(locale, 'hero_badge'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.getByLocale(locale, 'hero_title'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.getByLocale(locale, 'hero_description'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onOpenCertificates,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(
                    AppStrings.getByLocale(locale, 'hero_btn_certificates'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(
                    AppStrings.getByLocale(locale, 'hero_btn_platform'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            locale: locale,
            label: 'stat_languages',
            value: '12+',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            locale: locale,
            label: 'stat_tutorials',
            value: '15+',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            locale: locale,
            label: 'stat_exercises',
            value: '6+',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.locale,
    required this.label,
    required this.value,
  });

  final String locale;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              AppStrings.getByLocale(locale, label),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.locale,
    required this.onTap,
  });

  final LanguageMeta language;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  language.getLocalizedName(locale).characters.first,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                language.getLocalizedName(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  language.getLocalizedShortDescription(locale),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Text(
                    AppStrings.getByLocale(locale, 'btn_open'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title),
        ],
      ),
    );
  }
}
