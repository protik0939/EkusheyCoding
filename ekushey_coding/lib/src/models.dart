import 'dart:convert';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
  });

  final int id;
  final String name;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? 'user') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    required this.message,
  });

  final UserModel user;
  final String accessToken;
  final String tokenType;
  final String message;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(
        (json['user'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      accessToken: (json['access_token'] ?? json['token'] ?? '') as String,
      tokenType: (json['token_type'] ?? 'Bearer') as String,
      message: (json['message'] ?? '') as String,
    );
  }
}

class BlogPost {
  const BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    required this.titleBn,
    required this.excerpt,
    required this.excerptBn,
    required this.content,
    required this.contentBn,
    required this.author,
    required this.authorBn,
    required this.category,
    required this.categoryBn,
    required this.tags,
    required this.tagsBn,
    required this.readTime,
    required this.readTimeBn,
    required this.status,
    required this.views,
    this.imageUrl,
    this.publishedAt,
    this.createdAt,
  });

  final int id;
  final String slug;
  final String title;
  final String titleBn;
  final String excerpt;
  final String excerptBn;
  final String content;
  final String contentBn;
  final String author;
  final String authorBn;
  final String category;
  final String categoryBn;
  final List<String> tags;
  final List<String> tagsBn;
  final String readTime;
  final String readTimeBn;
  final String status;
  final int views;
  final String? imageUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  String titleByLocale(String locale) =>
      locale == 'bn' ? (titleBn.isNotEmpty ? titleBn : title) : title;
  String excerptByLocale(String locale) =>
      locale == 'bn' ? (excerptBn.isNotEmpty ? excerptBn : excerpt) : excerpt;
  String contentByLocale(String locale) =>
      locale == 'bn' ? (contentBn.isNotEmpty ? contentBn : content) : content;
  String categoryByLocale(String locale) => locale == 'bn'
      ? (categoryBn.isNotEmpty ? categoryBn : category)
      : category;
  String authorByLocale(String locale) =>
      locale == 'bn' ? (authorBn.isNotEmpty ? authorBn : author) : author;
  String readTimeByLocale(String locale) => locale == 'bn'
      ? (readTimeBn.isNotEmpty ? readTimeBn : readTime)
      : readTime;

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final categoryValue = json['category'];
    String category = '';
    String categoryBn = '';
    if (categoryValue is Map<String, dynamic>) {
      category = (categoryValue['category'] ?? '') as String;
      categoryBn = (categoryValue['category_bn'] ?? category) as String;
    } else {
      category = (categoryValue ?? '') as String;
      categoryBn = (json['category_bn'] ?? category) as String;
    }

    List<String> parseList(dynamic value) {
      if (value == null) return <String>[];
      if (value is List) return value.map((e) => '$e').toList();
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => '$e').toList();
          }
        } catch (_) {
          return value.isEmpty ? <String>[] : <String>[value];
        }
      }
      return <String>[];
    }

    final parsedTags = parseList(json['tags']);
    final parsedTagsBn = parseList(json['tags_bn']);

    return BlogPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      titleBn: (json['title_bn'] ?? '') as String,
      excerpt: (json['excerpt'] ?? '') as String,
      excerptBn: (json['excerpt_bn'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      contentBn: (json['content_bn'] ?? '') as String,
      author: (json['author'] ?? '') as String,
      authorBn: (json['author_bn'] ?? '') as String,
      category: category,
      categoryBn: categoryBn,
      tags: parsedTags,
      tagsBn: parsedTagsBn.isEmpty ? parsedTags : parsedTagsBn,
      readTime: (json['read_time'] ?? '') as String,
      readTimeBn: (json['read_time_bn'] ?? '') as String,
      status: (json['status'] ?? 'draft') as String,
      views: (json['views'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.tryParse('${json['published_at']}'),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse('${json['created_at']}'),
    );
  }
}

class TutorialItem {
  const TutorialItem({
    required this.id,
    required this.languageId,
    required this.title,
    required this.content,
    required this.order,
    required this.isPublished,
    this.codeExample,
  });

  final int id;
  final String languageId;
  final String title;
  final String content;
  final String? codeExample;
  final int order;
  final bool isPublished;

  factory TutorialItem.fromJson(Map<String, dynamic> json) {
    return TutorialItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      languageId: (json['language_id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      codeExample: json['code_example'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isPublished: (json['is_published'] ?? false) as bool,
    );
  }
}

class ExerciseItem {
  const ExerciseItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.titleBn,
    required this.problemStatement,
    required this.problemStatementBn,
    required this.inputDescription,
    required this.inputDescriptionBn,
    required this.outputDescription,
    required this.outputDescriptionBn,
    required this.sampleInput,
    required this.sampleInputBn,
    required this.sampleOutput,
    required this.sampleOutputBn,
    required this.difficulty,
    required this.difficultyBn,
    required this.languageId,
    required this.languageName,
    required this.languageNameBn,
    required this.tags,
    required this.tagsBn,
    required this.status,
    required this.views,
    required this.completions,
    this.category,
    this.categoryBn,
    this.description,
    this.descriptionBn,
    this.instructions,
    this.instructionsBn,
    this.starterCode,
    this.solutionCode,
    this.programmingLanguage,
    this.duration,
    this.imageUrl,
    this.publishedAt,
    this.createdAt,
  });

  final int id;
  final String slug;
  final String title;
  final String titleBn;
  final String? description;
  final String? descriptionBn;
  final String? instructions;
  final String? instructionsBn;
  final String problemStatement;
  final String problemStatementBn;
  final String inputDescription;
  final String inputDescriptionBn;
  final String outputDescription;
  final String outputDescriptionBn;
  final String sampleInput;
  final String sampleInputBn;
  final String sampleOutput;
  final String sampleOutputBn;
  final String difficulty;
  final String difficultyBn;
  final int? duration;
  final String? category;
  final String? categoryBn;
  final List<String> tags;
  final List<String> tagsBn;
  final String? starterCode;
  final String? solutionCode;
  final String? programmingLanguage;
  final String? languageId;
  final String? languageName;
  final String? languageNameBn;
  final String status;
  final int views;
  final int completions;
  final String? imageUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  String titleByLocale(String locale) =>
      locale == 'bn' ? (titleBn.isNotEmpty ? titleBn : title) : title;

  String problemByLocale(String locale) => locale == 'bn'
      ? (problemStatementBn.isNotEmpty ? problemStatementBn : problemStatement)
      : problemStatement;

  String inputByLocale(String locale) => locale == 'bn'
      ? (inputDescriptionBn.isNotEmpty ? inputDescriptionBn : inputDescription)
      : inputDescription;

  String outputByLocale(String locale) => locale == 'bn'
      ? (outputDescriptionBn.isNotEmpty
            ? outputDescriptionBn
            : outputDescription)
      : outputDescription;

  String sampleInputByLocale(String locale) => locale == 'bn'
      ? (sampleInputBn.isNotEmpty ? sampleInputBn : sampleInput)
      : sampleInput;

  String sampleOutputByLocale(String locale) => locale == 'bn'
      ? (sampleOutputBn.isNotEmpty ? sampleOutputBn : sampleOutput)
      : sampleOutput;

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value == null) return <String>[];
      if (value is List) return value.map((e) => '$e').toList();
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => '$e').toList();
          }
        } catch (_) {
          return value.isEmpty ? <String>[] : <String>[value];
        }
      }
      return <String>[];
    }

    final parsedTags = parseList(json['tags']);
    final parsedTagsBn = parseList(json['tags_bn']);

    return ExerciseItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      titleBn: (json['title_bn'] ?? '') as String,
      description: json['description'] as String?,
      descriptionBn: json['description_bn'] as String?,
      instructions: json['instructions'] as String?,
      instructionsBn: json['instructions_bn'] as String?,
      problemStatement: (json['problem_statement'] ?? '') as String,
      problemStatementBn: (json['problem_statement_bn'] ?? '') as String,
      inputDescription: (json['input_description'] ?? '') as String,
      inputDescriptionBn: (json['input_description_bn'] ?? '') as String,
      outputDescription: (json['output_description'] ?? '') as String,
      outputDescriptionBn: (json['output_description_bn'] ?? '') as String,
      sampleInput: (json['sample_input'] ?? '') as String,
      sampleInputBn: (json['sample_input_bn'] ?? '') as String,
      sampleOutput: (json['sample_output'] ?? '') as String,
      sampleOutputBn: (json['sample_output_bn'] ?? '') as String,
      difficulty: (json['difficulty'] ?? '') as String,
      difficultyBn: (json['difficulty_bn'] ?? '') as String,
      duration: (json['duration'] as num?)?.toInt(),
      category: json['category'] as String?,
      categoryBn: json['category_bn'] as String?,
      tags: parsedTags,
      tagsBn: parsedTagsBn.isEmpty ? parsedTags : parsedTagsBn,
      starterCode: json['starter_code'] as String?,
      solutionCode: json['solution_code'] as String?,
      programmingLanguage: json['programming_language'] as String?,
      languageId: json['language_id'] as String?,
      languageName: json['language_name'] as String?,
      languageNameBn: json['language_name_bn'] as String?,
      status: (json['status'] ?? 'draft') as String,
      views: (json['views'] as num?)?.toInt() ?? 0,
      completions: (json['completions'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.tryParse('${json['published_at']}'),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse('${json['created_at']}'),
    );
  }
}

class ProfileBundle {
  const ProfileBundle({
    required this.user,
    required this.profile,
    required this.stats,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> stats;

  factory ProfileBundle.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('success') && json.containsKey('data')) {
      final data =
          (json['data'] ?? <String, dynamic>{}) as Map<String, dynamic>;
      return ProfileBundle(
        user: (data['user'] ?? <String, dynamic>{}) as Map<String, dynamic>,
        profile:
            (data['profile'] ?? <String, dynamic>{}) as Map<String, dynamic>,
        stats: (data['stats'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      );
    }

    return ProfileBundle(
      user: (json['user'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      profile: (json['profile'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      stats: (json['stats'] ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }
}

class LanguageMeta {
  const LanguageMeta({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.version,
    required this.difficulty,
    required this.features,
    required this.useCases,
  });

  final String id;
  final String name;
  final String shortDescription;
  final String description;
  final String version;
  final String difficulty;
  final List<String> features;
  final List<String> useCases;
}

class DashboardStats {
  const DashboardStats({
    required this.totalBlogs,
    required this.publishedBlogs,
    required this.draftBlogs,
    required this.totalViews,
    required this.recentBlogs,
  });

  final int totalBlogs;
  final int publishedBlogs;
  final int draftBlogs;
  final int totalViews;
  final List<BlogPost> recentBlogs;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final recent = (json['recent_blogs'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (e) => BlogPost.fromJson(
            (e ?? <String, dynamic>{}) as Map<String, dynamic>,
          ),
        )
        .toList();

    return DashboardStats(
      totalBlogs: (json['total_blogs'] as num?)?.toInt() ?? 0,
      publishedBlogs: (json['published_blogs'] as num?)?.toInt() ?? 0,
      draftBlogs: (json['draft_blogs'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      recentBlogs: recent,
    );
  }
}
