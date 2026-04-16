import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  DashboardStats? _stats;
  List<BlogPost> _blogs = <BlogPost>[];
  List<ExerciseItem> _exercises = <ExerciseItem>[];
  List<TutorialItem> _tutorials = <TutorialItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    setState(() => _loading = true);

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        appState.adminService.fetchDashboardStats(token),
        appState.adminService.fetchAdminBlogs(token),
        appState.adminService.fetchAdminExercises(token),
        appState.adminService.fetchAdminTutorials(token),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as DashboardStats;
        _blogs = (results[1] as PaginatedList<BlogPost>).items;
        _exercises = (results[2] as PaginatedList<ExerciseItem>).items;
        _tutorials = results[3] as List<TutorialItem>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load admin data: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteBlog(int id) async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    try {
      await appState.adminService.deleteAdminBlog(token, id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Blog deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _deleteExercise(int id) async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    try {
      await appState.adminService.deleteAdminExercise(token, id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exercise deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _deleteTutorial(int id) async {
    final appState = context.read<AppState>();
    final token = appState.token;
    if (token == null) return;

    try {
      await appState.adminService.deleteAdminTutorial(token, id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tutorial deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAuthenticated || !appState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const GradientBackdrop(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStateCard(
                  title: 'Admin Access Required',
                  subtitle: 'Login with an admin account to access this area.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: 'Dashboard'),
            Tab(text: 'Blogs'),
            Tab(text: 'Exercises'),
            Tab(text: 'Tutorials'),
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
                    _AdminDashboardTab(stats: _stats),
                    _AdminBlogsTab(blogs: _blogs, onDelete: _deleteBlog),
                    _AdminExercisesTab(
                      exercises: _exercises,
                      onDelete: _deleteExercise,
                    ),
                    _AdminTutorialsTab(
                      tutorials: _tutorials,
                      onDelete: _deleteTutorial,
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
    );
  }
}

class _AdminDashboardTab extends StatelessWidget {
  const _AdminDashboardTab({required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          EmptyStateCard(
            title: 'No stats',
            subtitle: 'Dashboard data is unavailable.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        const SectionHeader(
          title: 'Overview',
          subtitle: 'Quick snapshot of content performance.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _StatBox(
              label: 'Total Blogs',
              value: '${stats!.totalBlogs}',
              icon: Icons.article_outlined,
            ),
            _StatBox(
              label: 'Published',
              value: '${stats!.publishedBlogs}',
              icon: Icons.visibility_outlined,
            ),
            _StatBox(
              label: 'Drafts',
              value: '${stats!.draftBlogs}',
              icon: Icons.edit_note_rounded,
            ),
            _StatBox(
              label: 'Views',
              value: '${stats!.totalViews}',
              icon: Icons.bar_chart_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBlogsTab extends StatelessWidget {
  const _AdminBlogsTab({required this.blogs, required this.onDelete});

  final List<BlogPost> blogs;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return _DataTableShell(
      emptyText: 'No blogs found',
      itemCount: blogs.length,
      itemBuilder: (_, index) {
        final blog = blogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(blog.title),
            subtitle: Text(
              '${blog.status} • ${blog.category} • ${blog.views} views',
            ),
            trailing: IconButton(
              onPressed: () => onDelete(blog.id),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _AdminExercisesTab extends StatelessWidget {
  const _AdminExercisesTab({required this.exercises, required this.onDelete});

  final List<ExerciseItem> exercises;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return _DataTableShell(
      emptyText: 'No exercises found',
      itemCount: exercises.length,
      itemBuilder: (_, index) {
        final ex = exercises[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(ex.title),
            subtitle: Text(
              '${ex.status} • ${ex.difficulty} • ${ex.views} views',
            ),
            trailing: IconButton(
              onPressed: () => onDelete(ex.id),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _AdminTutorialsTab extends StatelessWidget {
  const _AdminTutorialsTab({required this.tutorials, required this.onDelete});

  final List<TutorialItem> tutorials;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return _DataTableShell(
      emptyText: 'No tutorials found',
      itemCount: tutorials.length,
      itemBuilder: (_, index) {
        final t = tutorials[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(t.title),
            subtitle: Text(
              '${t.languageId} • order ${t.order} • ${t.isPublished ? 'published' : 'draft'}',
            ),
            trailing: IconButton(
              onPressed: () => onDelete(t.id),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _DataTableShell extends StatelessWidget {
  const _DataTableShell({
    required this.emptyText,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String emptyText;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          EmptyStateCard(
            title: emptyText,
            subtitle: 'No data available right now.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
