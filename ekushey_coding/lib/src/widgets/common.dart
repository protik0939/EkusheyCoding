import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF020617),
                  const Color(0xFF071325),
                  const Color(0xFF0B1220),
                ]
              : <Color>[
                  const Color(0xFFF8FAFC),
                  const Color(0xFFEFF6FF),
                  const Color(0xFFF0FDF4),
                ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -100,
            left: -80,
            child: _Orb(color: kBrandGreen.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: _Orb(color: kBrandEmerald.withValues(alpha: 0.16)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final isDark =
            appState.themeMode == 'dark' ||
            (appState.themeMode == 'system' &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          onPressed: () async {
            await appState.toggleThemeMode();
            onPressed?.call();
          },
          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
        );
      },
    );
  }
}

class ThemeModeSwitcher extends StatelessWidget {
  const ThemeModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Light Mode'),
              leading: const Icon(Icons.light_mode_rounded),
              selected: appState.themeMode == 'light',
              onTap: () async {
                await appState.setThemeMode('light');
              },
            ),
            ListTile(
              title: const Text('Dark Mode'),
              leading: const Icon(Icons.dark_mode_rounded),
              selected: appState.themeMode == 'dark',
              onTap: () async {
                await appState.setThemeMode('dark');
              },
            ),
            ListTile(
              title: const Text('System Default'),
              leading: const Icon(Icons.brightness_auto_rounded),
              selected: appState.themeMode == 'system',
              onTap: () async {
                await appState.setThemeMode('system');
              },
            ),
          ],
        );
      },
    );
  }
}
