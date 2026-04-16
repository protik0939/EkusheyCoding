import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
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
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAuthenticated) {
      return GradientBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              const EmptyStateCard(
                title: 'Login Required',
                subtitle:
                    'Sign in to view your profile, learning stats, and saved progress.',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onLogin,
                      child: const Text('Login'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSignup,
                      child: const Text('Create Account'),
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
                title: 'Profile',
                subtitle: 'Manage your account and learning information.',
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
                const EmptyStateCard(
                  title: 'Profile unavailable',
                  subtitle: 'Could not load your profile right now.',
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
                                'Courses: ${profile.stats['total_courses'] ?? 0}',
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
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Logged out successfully'),
                          ),
                        );
                      },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
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
