import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onLogin,
    required this.onSignup,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileBundle? _profile;
  bool _loading = false;
  bool _editing = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.watch<AppState>();
    if (appState.isAuthenticated && _profile == null && !_loading) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final profile = await appState.profileService.getProfile(token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameCtrl.text = '${profile.user['name'] ?? ''}';
        _emailCtrl.text = '${profile.user['email'] ?? ''}';
        _usernameCtrl.text = '${profile.profile['username'] ?? ''}';
        _phoneCtrl.text = '${profile.profile['phone'] ?? ''}';
        _bioCtrl.text = '${profile.profile['bio'] ?? ''}';
        _locationCtrl.text = '${profile.profile['location'] ?? ''}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.getByLocale(context.read<AppState>().locale, 'failed_load_profile')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      await appState.profileService.updateBasicInfo(
        token,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      await appState.profileService.updateDetails(token, <String, dynamic>{
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
      });
      await appState.refreshCurrentUser();
      await _loadProfile();
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.getByLocale(
              context.read<AppState>().locale,
              'profile_updated',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.getByLocale(context.read<AppState>().locale, 'failed_save_profile')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final locale = appState.locale;

    if (!appState.isAuthenticated) {
      return GradientBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              EmptyStateCard(
                title: AppStrings.getByLocale(locale, 'login_required'),
                subtitle: AppStrings.getByLocale(
                  locale,
                  'login_required_subtitle',
                ),
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onLogin,
                      child: Text(AppStrings.getByLocale(locale, 'btn_login')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSignup,
                      child: Text(AppStrings.getByLocale(locale, 'btn_signup')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile;

    return GradientBackdrop(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              SectionHeader(
                title: AppStrings.getByLocale(locale, 'profile_title'),
                subtitle: AppStrings.getByLocale(locale, 'profile_subtitle'),
                trailing: IconButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (_editing) {
                            _saveProfile();
                          } else {
                            setState(() => _editing = true);
                          }
                        },
                  icon: Icon(
                    _editing ? Icons.save_rounded : Icons.edit_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading && profile == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (profile == null)
                EmptyStateCard(
                  title: AppStrings.getByLocale(locale, 'profile_unavailable'),
                  subtitle: AppStrings.getByLocale(
                    locale,
                    'profile_unavailable_subtitle',
                  ),
                )
              else ...<Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 34,
                          child: Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text.characters.first.toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FieldRow(
                          label: 'Name',
                          controller: _nameCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          label: 'Email',
                          controller: _emailCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          label: 'Username',
                          controller: _usernameCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          label: 'Phone',
                          controller: _phoneCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          label: 'Location',
                          controller: _locationCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          label: 'Bio',
                          controller: _bioCtrl,
                          enabled: _editing,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Learning Stats',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Chip(
                              label: Text(
                                '${AppStrings.getByLocale(locale, 'enroll')}: ${profile.stats['total_courses'] ?? 0}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Hours: ${profile.stats['hours_learned'] ?? 0}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Certificates: ${profile.stats['certificates_earned'] ?? 0}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Streak: ${profile.stats['current_streak'] ?? 0}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await appState.logout();
                        if (!mounted) return;
                        final msg =
                            '${AppStrings.getByLocale(locale, 'logout')} ${AppStrings.getByLocale(locale, 'success')}';
                        messenger.showSnackBar(SnackBar(content: Text(msg)));
                      },
                icon: const Icon(Icons.logout_rounded),
                label: Text(AppStrings.getByLocale(locale, 'logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.controller,
    required this.enabled,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}
