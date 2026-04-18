import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'data/strings.dart';
import 'data/languages.dart';
import 'models.dart';
import 'screens/admin_screen.dart';
import 'screens/blog_detail_screen.dart';
import 'screens/blog_screen.dart';
import 'screens/certificates_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/tutorials_screen.dart';
import 'session_store.dart';
import 'theme.dart';
import 'widgets/common.dart';

ThemeMode _stringToThemeMode(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

class EkusheyCodingApp extends StatelessWidget {
  const EkusheyCodingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(sessionStore: SessionStore())..initialize(),
      child: Consumer<AppState>(
        builder: (BuildContext context, AppState appState, _) {
          return MaterialApp(
            title: AppStrings.getByLocale(appState.locale, 'app_title'),
            debugShowCheckedModeBanner: false,
            theme: buildEkusheyTheme(Brightness.light),
            darkTheme: buildEkusheyTheme(Brightness.dark),
            themeMode: _stringToThemeMode(appState.themeMode),
            home: appState.isInitialized
                ? const AppShell()
                : const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openLanguage(LanguageMeta language) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LanguageDetailScreen(language: language),
      ),
    );
  }

  void _openBlog(BlogPost post) {
    final locale = context.read<AppState>().locale;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlogDetailScreen(post: post, locale: locale),
      ),
    );
  }

  void _openCertificates() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CertificatesScreen()));
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          onSuccess: () => Navigator.of(context).pop(),
          onOpenSignup: () {
            Navigator.of(context).pop();
            _openSignup();
          },
        ),
      ),
    );
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignupScreen(
          onSuccess: () => Navigator.of(context).pop(),
          onOpenLogin: () {
            Navigator.of(context).pop();
            _openLogin();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final screens = <Widget>[
      HomeScreen(
        onOpenLanguage: _openLanguage,
        onOpenCertificates: _openCertificates,
      ),
      TutorialsScreen(onOpenLanguage: _openLanguage),
      ExercisesScreen(onOpenLanguage: _openLanguage),
      BlogScreen(onOpenBlog: _openBlog),
      ProfileScreen(onLogin: _openLogin, onSignup: _openSignup),
    ];

    final labels = <String>[
      AppStrings.getByLocale(appState.locale, 'page_home'),
      AppStrings.getByLocale(appState.locale, 'page_tutorials'),
      AppStrings.getByLocale(appState.locale, 'page_exercises'),
      AppStrings.getByLocale(appState.locale, 'page_blog'),
      AppStrings.getByLocale(appState.locale, 'page_profile'),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Image.asset('assets/brand_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            Text(labels[_index]),
          ],
        ),
        actions: <Widget>[
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: () {
              final locale = appState.locale == 'en' ? 'bn' : 'en';
              appState.setLocale(locale);
            },
            icon: const Icon(Icons.language_rounded),
            label: Text(
              appState.locale == 'en'
                  ? AppStrings.getByLocale(appState.locale, 'bangla')
                  : AppStrings.getByLocale(appState.locale, 'english'),
            ),
          ),
          if (!appState.isAuthenticated)
            IconButton(
              tooltip: AppStrings.getByLocale(appState.locale, 'btn_login'),
              onPressed: _openLogin,
              icon: const Icon(Icons.login_rounded),
            )
          else
            IconButton(
              tooltip: AppStrings.getByLocale(appState.locale, 'logout'),
              onPressed: () => appState.logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      drawer: _GlassDrawer(
        appState: appState,
        onOpenCertificates: () {
          Navigator.of(context).pop();
          _openCertificates();
        },
        onOpenAllLanguages: () {
          Navigator.of(context).pop();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _LanguagePicker(onOpenLanguage: _openLanguage),
          );
        },
        onOpenAdmin: appState.isAdmin
            ? () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
                );
              }
            : null,
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _LiquidGlassBottomNav(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <_LiquidGlassDestination>[
          _LiquidGlassDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _LiquidGlassDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            label: 'Tutorials',
          ),
          _LiquidGlassDestination(
            icon: Icons.code_outlined,
            selectedIcon: Icons.code_rounded,
            label: 'Exercises',
          ),
          _LiquidGlassDestination(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article_rounded,
            label: 'Blog',
          ),
          _LiquidGlassDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassDestination {
  const _LiquidGlassDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _GlassDrawer extends StatelessWidget {
  const _GlassDrawer({
    required this.appState,
    required this.onOpenCertificates,
    required this.onOpenAllLanguages,
    required this.onOpenAdmin,
  });

  final AppState appState;
  final VoidCallback onOpenCertificates;
  final VoidCallback onOpenAllLanguages;
  final VoidCallback? onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.white.withValues(alpha: 0.82),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? <Color>[
                            const Color(0xE60B1220),
                            const Color(0xCC111827),
                            const Color(0xCC1F2937),
                          ]
                        : <Color>[
                            const Color(0xE6FFFFFF),
                            const Color(0xDDF8FAFC),
                            const Color(0xCCEFF6FF),
                          ],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: Image.asset(
                                  'assets/brand_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Ekushey Coding',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Locale: ${appState.locale.toUpperCase()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DrawerActionTile(
                      icon: Icons.workspace_premium_rounded,
                      title: AppStrings.getByLocale(
                        appState.locale,
                        'page_certificates',
                      ),
                      subtitle: AppStrings.getByLocale(
                        appState.locale,
                        'certificates_subtitle',
                      ),
                      onTap: onOpenCertificates,
                    ),
                    const SizedBox(height: 8),
                    _DrawerActionTile(
                      icon: Icons.language_rounded,
                      title: AppStrings.getByLocale(
                        appState.locale,
                        'all_languages',
                      ),
                      subtitle: AppStrings.getByLocale(
                        appState.locale,
                        'all_languages_subtitle',
                      ),
                      onTap: onOpenAllLanguages,
                    ),
                    if (onOpenAdmin != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _DrawerActionTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: AppStrings.getByLocale(
                          appState.locale,
                          'admin_title',
                        ),
                        subtitle: AppStrings.getByLocale(
                          appState.locale,
                          'admin_panel_subtitle',
                        ),
                        onTap: onOpenAdmin!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.55),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassBottomNav extends StatelessWidget {
  const _LiquidGlassBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<_LiquidGlassDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SizedBox(
        height: 78,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.72),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? <Color>[
                          const Color(0xCC0B1220),
                          const Color(0xCC111827),
                          const Color(0xCC1F2937),
                        ]
                      : <Color>[
                          const Color(0xD9FFFFFF),
                          const Color(0xCFF8FAFC),
                          const Color(0xCCEFF6FF),
                        ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: List<Widget>.generate(destinations.length, (
                    int index,
                  ) {
                    final destination = destinations[index];
                    final selected = index == selectedIndex;

                    return Expanded(
                      child: _LiquidGlassNavItem(
                        destination: destination,
                        selected: selected,
                        onTap: () => onDestinationSelected(index),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassNavItem extends StatelessWidget {
  const _LiquidGlassNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _LiquidGlassDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.82 : 0.74);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.95,
                          ),
                          theme.colorScheme.primary.withValues(alpha: 0.70),
                        ],
                      )
                    : null,
                border: selected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.45))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: foreground,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.onOpenLanguage});

  final ValueChanged<LanguageMeta> onOpenLanguage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        itemCount: kLanguages.length,
        itemBuilder: (_, index) {
          final item = kLanguages[index];
          return ListTile(
            leading: CircleAvatar(child: Text(item.name.characters.first)),
            title: Text(item.name),
            subtitle: Text(
              item.shortDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(context).pop();
              onOpenLanguage(item);
            },
          );
        },
      ),
    );
  }
}
