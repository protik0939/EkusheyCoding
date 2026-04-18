import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/strings.dart';
import '../models.dart';
import '../widgets/common.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key, required this.onOpenBlog});

  final ValueChanged<BlogPost> onOpenBlog;

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedCategory = 'All';
  List<String> _categories = <String>['All'];
  List<BlogPost> _blogs = <BlogPost>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait(<Future<void>>[
      _loadCategories(),
      _loadBlogs(reset: true),
    ]);
  }

  Future<void> _loadCategories() async {
    final appState = context.read<AppState>();
    try {
      final values = await appState.contentService.fetchBlogCategories();
      if (!mounted) return;
      setState(() {
        _categories = values;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = <String>['All'];
      });
    }
  }

  Future<void> _loadBlogs({required bool reset}) async {
    final appState = context.read<AppState>();

    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await appState.contentService.fetchBlogs(
        page: reset ? 1 : _page + 1,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        category: _selectedCategory,
      );

      if (!mounted) return;

      setState(() {
        _blogs = reset ? result.items : <BlogPost>[..._blogs, ...result.items];
        _page = result.currentPage;
        _lastPage = result.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.getByLocale(context.read<AppState>().locale, 'failed_load_blog')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppState>().locale;
    final featured = _blogs.isEmpty ? null : _blogs.first;

    return GradientBackdrop(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadBlogs(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              const SectionHeader(
                title: 'Coding Blog',
                subtitle:
                    'Discover practical coding guides and development insights.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadBlogs(reset: true),
                decoration: InputDecoration(
                  hintText: 'Search articles by title or topic...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadBlogs(reset: true);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final category = _categories[index];
                    final selected = category == _selectedCategory;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(category),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                        _loadBlogs(reset: true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...<Widget>[
                if (featured != null)
                  _FeaturedBlogCard(
                    post: featured,
                    locale: locale,
                    onTap: () => widget.onOpenBlog(featured),
                  ),
                const SizedBox(height: 12),
                if (_blogs.length <= 1)
                  const EmptyStateCard(
                    title: 'No blogs found',
                    subtitle: 'Try a different search keyword or category.',
                  )
                else
                  ..._blogs
                      .skip(1)
                      .map(
                        (BlogPost post) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BlogListTile(
                            post: post,
                            locale: locale,
                            onTap: () => widget.onOpenBlog(post),
                          ),
                        ),
                      ),
                if (_page < _lastPage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: _loadingMore
                          ? null
                          : () => _loadBlogs(reset: false),
                      icon: _loadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(_loadingMore ? 'Loading...' : 'Load More'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedBlogCard extends StatelessWidget {
  const _FeaturedBlogCard({
    required this.post,
    required this.locale,
    required this.onTap,
  });

  final BlogPost post;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.categoryByLocale(locale),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                post.titleByLocale(locale),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                post.excerptByLocale(locale),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(post.authorByLocale(locale)),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(post.readTimeByLocale(locale)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlogListTile extends StatelessWidget {
  const _BlogListTile({
    required this.post,
    required this.locale,
    required this.onTap,
  });

  final BlogPost post;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          post.titleByLocale(locale),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            post.excerptByLocale(locale),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
