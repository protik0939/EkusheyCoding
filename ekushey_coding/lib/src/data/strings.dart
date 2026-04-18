/// Localized strings for Ekushey Coding app
/// Supports English (en) and Bangla (bn)

class AppStrings {
  static String getByLocale(String locale, String key) {
    if (locale == 'bn') {
      return _bengaliStrings[key] ?? _englishStrings[key] ?? key;
    }
    return _englishStrings[key] ?? key;
  }

  // English translations
  static const Map<String, String> _englishStrings = {
    // Hero card
    'hero_badge': 'Learn to Code. Build the Future.',
    'hero_title': 'Ekushey Coding Mobile',
    'hero_description':
        'Tutorials, exercises, blogs, profile tracking, and admin content management - all in one responsive Flutter app.',
    'hero_btn_certificates': 'Explore Certificates',
    'hero_btn_platform': 'Built for Mobile + Web',
    // Profile & common
    'login_required': 'Login Required',
    'login_required_subtitle':
        'Sign in to view your profile, learning stats, and saved progress.',
    'profile_title': 'Profile',
    'profile_subtitle': 'Manage your account and learning information.',
    'profile_unavailable': 'Profile unavailable',
    'profile_unavailable_subtitle': 'Could not load your profile right now.',
    'failed_load_profile': 'Failed to load profile',
    'failed_save_profile': 'Failed to save profile',
    'profile_updated': 'Profile updated successfully',
    'logged_out_success': 'Logged out successfully',
    'success': 'success',

    // Stats
    'stat_languages': 'Languages',
    'stat_tutorials': 'Tutorials',
    'stat_exercises': 'Exercises',

    // Programming Languages Section
    'section_languages': 'Programming Languages',
    'section_languages_subtitle':
        'Pick your track and start learning with tutorials and exercises.',
    'btn_certificates': 'Certificates',

    // Why Ekushey Section
    'section_why': 'Why Ekushey Coding',
    'section_why_subtitle':
        'A responsive, bilingual, practical learning path inspired by your web platform.',

    // Feature chips
    'feature_hands_on': 'Hands-on Exercises',
    'feature_bilingual': 'English + Bangla Content',
    'feature_tutorial_first': 'Tutorial-First Learning',
    'feature_admin': 'Admin Management Ready',

    // Language card
    'btn_open': 'Open',

    // Programming Languages - Names and Descriptions
    'lang_javascript_name': 'JavaScript',
    'lang_javascript_desc':
        'A versatile programming language for web development',
    'lang_python_name': 'Python',
    'lang_python_desc': 'A powerful language for data science and automation',
    'lang_java_name': 'Java',
    'lang_java_desc': 'Enterprise-grade object-oriented programming',
    'lang_cpp_name': 'C++',
    'lang_cpp_desc': 'High-performance system programming language',
    'lang_csharp_name': 'C#',
    'lang_csharp_desc': 'Modern language for .NET development',
    'lang_typescript_name': 'TypeScript',
    'lang_typescript_desc': 'JavaScript with static typing',
    'lang_php_name': 'PHP',
    'lang_php_desc': 'Server-side scripting for web development',
    'lang_ruby_name': 'Ruby',
    'lang_ruby_desc': 'Elegant language focused on simplicity',
    'lang_go_name': 'Go',
    'lang_go_desc': 'Fast and efficient for concurrent systems',
    'lang_rust_name': 'Rust',
    'lang_rust_desc': 'Memory-safe systems programming',
    'lang_swift_name': 'Swift',
    'lang_swift_desc': 'Modern language for iOS development',
    'lang_kotlin_name': 'Kotlin',
    'lang_kotlin_desc': 'Modern language for Android development',

    // Tutorials Screen
    'page_tutorials': 'Tutorials',
    'tutorials_subtitle':
        'Step-by-step lessons grouped by programming language.',
    'filter_all': 'All',
    'empty_tutorials_title': 'No tutorials available',
    'empty_tutorials_subtitle':
        'Tutorials for this language will appear once published.',
    'lessons_count': 'lessons',
    'failed_load_tutorials': 'Failed to load tutorials',

    // Exercises Screen
    'page_exercises': 'Exercises',
    'exercises_subtitle': 'Practice problems to strengthen your skills.',
    'empty_exercises_title': 'No exercises available',
    'empty_exercises_subtitle':
        'Exercises for this language will appear once published.',
    'exercises_count': 'problems',
    'difficulty': 'Difficulty',
    'difficulty_beginner': 'Beginner',
    'difficulty_intermediate': 'Intermediate',
    'difficulty_advanced': 'Advanced',
    'difficulty_easy': 'Easy',
    'difficulty_medium': 'Medium',
    'difficulty_hard': 'Hard',
    'duration': 'Duration',
    'failed_load_exercises': 'Failed to load exercises',
    'empty_exercises_found_title': 'No exercises found',
    'empty_exercises_found_subtitle': 'Try changing filters or search terms.',
    'label_problem': 'Problem',
    'label_input': 'Input',
    'label_output': 'Output',
    'label_sample_input': 'Sample Input',
    'label_sample_output': 'Sample Output',
    'label_starter_code': 'Starter Code',
    'label_solution_code': 'Solution Code',

    // Blog Screen
    'page_blog': 'Blog',
    'blog_subtitle': 'Articles and insights from our community.',
    'search_articles_hint': 'Search articles by title or topic...',
    'load_more': 'Load More',
    'loading': 'Loading...',
    'empty_blog_title': 'No articles available',
    'empty_blog_subtitle': 'Check back later for new content.',
    'posts_count': 'articles',
    'published': 'Published',
    'failed_load_blog': 'Failed to load blog posts',

    // Profile Screen
    'page_profile': 'Profile',
    'profile_login_title': 'Welcome Back',
    'profile_login_subtitle': 'Sign in to track your progress.',
    'btn_login': 'Login',
    'btn_signup': 'Sign Up',
    'profile_stats': 'Your Stats',
    'lessons_completed': 'Lessons Completed',
    'exercises_solved': 'Exercises Solved',
    'blogs_read': 'Blogs Read',
    'logout': 'Logout',

    // Certificates Screen
    'page_certificates': 'Certificates',
    'certificates_subtitle': 'Earn certificates by completing courses.',
    'empty_certificates_title': 'No certificates earned yet',
    'empty_certificates_subtitle':
        'Complete courses to earn your certificates.',
    'earned': 'Earned',
    'failed_load_certificates': 'Failed to load certificates',

    // Tutorial Detail Screen
    'code_example': 'Code Example',
    'details': 'Details',
    'language_label': 'Language',
    'lesson_number': 'Lesson Number',
    'status': 'Status',
    'status_published': 'Published',
    'status_draft': 'Draft',
    'content_language': 'Content Language',
    'english': 'English',
    'bangla': 'Bangla',

    // Language Detail Screen
    'version': 'Version',
    'lesson': 'Lesson',
    'key_features': 'Key Features',
    'use_cases': 'Use Cases',
    'quick_quiz': 'Quick Quiz',
    'check_answers': 'Check Answers',
    'reset': 'Reset',
    'quiz_q1': 'What keyword is commonly used for constant values?',
    'quiz_q1_opt0': 'var',
    'quiz_q1_opt1': 'let',
    'quiz_q1_opt2': 'const',
    'quiz_q1_opt3': 'finalize',
    'quiz_q2': 'Which command prints output in most languages?',
    'quiz_q2_opt0': 'echo()',
    'quiz_q2_opt1': 'log()',
    'quiz_q2_opt2': 'print()/console.log()',
    'quiz_q2_opt3': 'writeLineForever()',
    'quiz_q3': 'What helps keep code maintainable?',
    'quiz_q3_opt0': 'Long files only',
    'quiz_q3_opt1': 'No naming conventions',
    'quiz_q3_opt2': 'Reusable functions/modules',
    'quiz_q3_opt3': 'No comments ever',
    'score_label': 'Score',
    'about_tab': 'About',
    'tutorials_tab': 'Tutorials',
    'exercises_tab': 'Exercises',
    'blog_details': 'Blog Details',
    'login_title': 'Login',
    'login_button': 'Login',
    'login_welcome': 'Welcome back',
    'login_subtitle': 'Sign in to continue learning and managing your profile.',
    'label_email': 'Email',
    'err_email_required': 'Email is required',
    'err_email_invalid': 'Enter a valid email',
    'err_password_required': 'Password is required',
    'password': 'Password',
    'confirm_password': 'Confirm Password',
    'create_account': 'Create account',
    'no_account': 'No account? Create one',
    'already_account': 'Already have an account? Login',
    'certificates_title': 'Certificates',
    'enroll': 'Enroll',
    'admin_title': 'Admin',
    'admin_panel_title': 'Admin Panel',
    'refresh': 'Refresh',
    'signup_subtitle':
        'Join Ekushey Coding to track progress and access profile features.',
    'label_name': 'Name',
    'err_name_required': 'Name is required',
    'err_min_password': 'Minimum 8 characters',
    'err_confirm_password': 'Confirm your password',
    'err_password_mismatch': 'Passwords do not match',
    // App / UI
    'app_title': 'Ekushey Coding',
    'page_home': 'Home',
    'all_languages': 'All Languages',
    'all_languages_subtitle': 'Open the full language list',
    'locale_label': 'Locale:',
    'views': 'views',
    'label_level': 'Level',
    'label_duration': 'Duration',
    // Theme
    'theme_light': 'Light Mode',
    'theme_dark': 'Dark Mode',
    'theme_system': 'System Default',
    // Admin
    'admin_panel_subtitle': 'Manage blogs, tutorials, and exercises',
  };

  // Bangla translations
  static const Map<String, String> _bengaliStrings = {
    // Hero card
    'hero_badge': 'কোড করতে শিখুন। ভবিষ্যৎ তৈরি করুন।',
    'hero_title': 'একুশে কোডিং মোবাইল',
    'hero_description':
        'টিউটোরিয়াল, এক্সারসাইজ, ব্লগ, প্রোফাইল ট্র্যাকিং এবং অ্যাডমিন কন্টেন্ট ম্যানেজমেন্ট - সবকিছু একটি রেসপন্সিভ ফ্লাটার অ্যাপে।',
    'hero_btn_certificates': 'সার্টিফিকেট দেখুন',
    'hero_btn_platform': 'মোবাইল + ওয়েব এর জন্য তৈরি',
    // Profile & common
    'login_required': 'লগইন প্রয়োজন',
    'login_required_subtitle':
        'আপনার প্রোফাইল, শেখার স্ট্যাটস এবং সংরক্ষিত অগ্রগতি দেখতে সাইন ইন করুন।',
    'profile_title': 'প্রোফাইল',
    'profile_subtitle': 'আপনার অ্যাকাউন্ট এবং শেখার তথ্য পরিচালনা করুন।',
    'profile_unavailable': 'প্রোফাইল উপলব্ধ নেই',
    'profile_unavailable_subtitle': 'এখন আপনার প্রোফাইল লোড করা যাচ্ছে না।',
    'failed_load_profile': 'প্রোফাইল লোড করতে ব্যর্থ',
    'failed_save_profile': 'প্রোফাইল সংরক্ষণে ব্যর্থ',
    'profile_updated': 'প্রোফাইল সফলভাবে আপডেট হয়েছে',
    'logged_out_success': 'সফলভাবে লগআউট হয়েছে',
    'success': 'সফল',

    // Stats
    'stat_languages': 'ভাষা',
    'stat_tutorials': 'টিউটোরিয়াল',
    'stat_exercises': 'এক্সারসাইজ',

    // Programming Languages Section
    'section_languages': 'প্রোগ্রামিং ভাষা',
    'section_languages_subtitle':
        'আপনার ট্র্যাক বেছে নিন এবং টিউটোরিয়াল এবং এক্সারসাইজের সাথে শিখতে শুরু করুন।',
    'btn_certificates': 'সার্টিফিকেট',

    // Why Ekushey Section
    'section_why': 'কেন একুশে কোডিং',
    'section_why_subtitle':
        'একটি রেসপন্সিভ, দ্বিভাষিক, বাস্তবিক শিক্ষার পথ যা আপনার ওয়েব প্ল্যাটফর্ম থেকে অনুপ্রাণিত।',

    // Feature chips
    'feature_hands_on': 'হাতে-কলমে এক্সারসাইজ',
    'feature_bilingual': 'ইংরেজি + বাংলা কন্টেন্ট',
    'feature_tutorial_first': 'টিউটোরিয়াল-প্রথম শিক্ষা',
    'feature_admin': 'অ্যাডমিন ম্যানেজমেন্ট প্রস্তুত',

    // Language card
    'btn_open': 'খুলুন',

    // Programming Languages - Names and Descriptions
    'lang_javascript_name': 'জাভাস্ক্রিপ্ট',
    'lang_javascript_desc':
        'ওয়েব ডেভেলপমেন্টের জন্য একটি বহুমুখী প্রোগ্রামিং ভাষা',
    'lang_python_name': 'পাইথন',
    'lang_python_desc': 'ডেটা সায়েন্স এবং অটোমেশনের জন্য একটি শক্তিশালী ভাষা',
    'lang_java_name': 'জাভা',
    'lang_java_desc': 'এন্টারপ্রাইজ-গ্রেড অবজেক্ট-ওরিয়েন্টেড প্রোগ্রামিং',
    'lang_cpp_name': 'সি++',
    'lang_cpp_desc': 'উচ্চ-কর্মক্ষমতা সিস্টেম প্রোগ্রামিং ভাষা',
    'lang_csharp_name': 'সি#',
    'lang_csharp_desc': '.NET ডেভেলপমেন্টের জন্য আধুনিক ভাষা',
    'lang_typescript_name': 'টাইপস্ক্রিপ্ট',
    'lang_typescript_desc': 'স্ট্যাটিক টাইপিং সহ জাভাস্ক্রিপ্ট',
    'lang_php_name': 'পিএইচপি',
    'lang_php_desc': 'ওয়েব ডেভেলপমেন্টের জন্য সার্ভার-সাইড স্ক্রিপটিং',
    'lang_ruby_name': 'রুবি',
    'lang_ruby_desc': 'সরলতার উপর ফোকাস করা মার্জিত ভাষা',
    'lang_go_name': 'গো',
    'lang_go_desc': 'সমন্বিত সিস্টেমের জন্য দ্রুত এবং দক্ষ',
    'lang_rust_name': 'রাস্ট',
    'lang_rust_desc': 'মেমরি-নিরাপদ সিস্টেম প্রোগ্রামিং',
    'lang_swift_name': 'সুইফট',
    'lang_swift_desc': 'আইওএস ডেভেলপমেন্টের জন্য আধুনিক ভাষা',
    'lang_kotlin_name': 'কটলিন',
    'lang_kotlin_desc': 'অ্যান্ড্রয়েড ডেভেলপমেন্টের জন্য আধুনিক ভাষা',

    // Tutorials Screen
    'page_tutorials': 'টিউটোরিয়াল',
    'tutorials_subtitle': 'প্রোগ্রামিং ভাষা অনুযায়ী সংগঠিত ধাপে ধাপে পাঠ।',
    'filter_all': 'সব',
    'empty_tutorials_title': 'কোনো টিউটোরিয়াল উপলব্ধ নেই',
    'empty_tutorials_subtitle':
        'এই ভাষার টিউটোরিয়াল প্রকাশিত হলে এখানে প্রদর্শিত হবে।',
    'lessons_count': 'পাঠ',
    'failed_load_tutorials': 'টিউটোরিয়াল লোড করতে ব্যর্থ',

    // Exercises Screen
    'page_exercises': 'এক্সারসাইজ',
    'exercises_subtitle': 'আপনার দক্ষতা শক্তিশালী করতে অনুশীলন সমস্যা।',
    'empty_exercises_title': 'কোনো এক্সারসাইজ উপলব্ধ নেই',
    'empty_exercises_subtitle':
        'এই ভাষার এক্সারসাইজ প্রকাশিত হলে এখানে প্রদর্শিত হবে।',
    'exercises_count': 'সমস্যা',
    'difficulty': 'কঠিনতা',
    'difficulty_beginner': 'শুরুতি',
    'difficulty_intermediate': 'মাঝারি',
    'difficulty_advanced': 'উন্নত',
    'difficulty_easy': 'সহজ',
    'difficulty_medium': 'মধ্যম',
    'difficulty_hard': 'কঠিন',
    'duration': 'সময়কাল',
    'failed_load_exercises': 'এক্সারসাইজ লোড করতে ব্যর্থ',
    'empty_exercises_found_title': 'কোনো এক্সারসাইজ পাওয়া যায়নি',
    'empty_exercises_found_subtitle': 'ফিল্টার বা সার্চ শর্ত পরিবর্তন করে দেখুন।',
    'label_problem': 'সমস্যা',
    'label_input': 'ইনপুট',
    'label_output': 'আউটপুট',
    'label_sample_input': 'নমুনা ইনপুট',
    'label_sample_output': 'নমুনা আউটপুট',
    'label_starter_code': 'স্টার্টার কোড',
    'label_solution_code': 'সমাধান কোড',

    // Blog Screen
    'page_blog': 'ব্লগ',
    'blog_subtitle': 'আমাদের কমিউনিটি থেকে নিবন্ধ এবং অন্তর্দৃষ্টি।',
    'search_articles_hint': 'শিরোনাম বা টপিক দিয়ে নিবন্ধ খুঁজুন...',
    'load_more': 'আরো লোড করুন',
    'loading': 'লোড হচ্ছে...',
    'empty_blog_title': 'কোনো নিবন্ধ উপলব্ধ নেই',
    'empty_blog_subtitle': 'নতুন কন্টেন্টের জন্য পরে ফিরে দেখুন।',
    'posts_count': 'নিবন্ধ',
    'published': 'প্রকাশিত',
    'failed_load_blog': 'ব্লগ পোস্ট লোড করতে ব্যর্থ',

    // Profile Screen
    'page_profile': 'প্রোফাইল',
    'profile_login_title': 'আবার স্বাগতম',
    'profile_login_subtitle': 'আপনার অগ্রগতি ট্র্যাক করতে সাইন ইন করুন।',
    'btn_login': 'লগইন',
    'btn_signup': 'সাইন আপ',
    'profile_stats': 'আপনার পরিসংখ্যান',
    'lessons_completed': 'সম্পন্ন পাঠ',
    'exercises_solved': 'সমাধান করা এক্সারসাইজ',
    'blogs_read': 'পড়া ব্লগ',
    'logout': 'লগআউট',

    // Certificates Screen
    'page_certificates': 'সার্টিফিকেট',
    'certificates_subtitle': 'কোর্স সম্পন্ন করে সার্টিফিকেট অর্জন করুন।',
    'empty_certificates_title': 'এখনও কোনো সার্টিফিকেট অর্জন করা হয়নি',
    'empty_certificates_subtitle': 'সার্টিফিকেট অর্জন করতে কোর্স সম্পন্ন করুন।',
    'earned': 'অর্জিত',
    'failed_load_certificates': 'সার্টিফিকেট লোড করতে ব্যর্থ',

    // Tutorial Detail Screen
    'code_example': 'কোড উদাহরণ',
    'details': 'বিবরণ',
    'language_label': 'ভাষা',
    'lesson_number': 'পাঠ সংখ্যা',
    'status': 'অবস্থা',
    'status_published': 'প্রকাশিত',
    'status_draft': 'খসড়া',
    'content_language': 'বিষয়বস্তু ভাষা',
    'english': 'ইংরেজি',
    'bangla': 'বাংলা',

    // Language Detail Screen
    'version': 'সংস্করণ',
    'lesson': 'পাঠ',
    'key_features': 'মূল বৈশিষ্ট্য',
    'use_cases': 'ব্যবহারের ক্ষেত্র',
    'quick_quiz': 'দ্রুত কুইজ',
    'check_answers': 'উত্তর যাচাই করুন',
    'reset': 'পুনরায় সেট করুন',
    'quiz_q1': 'ধ্রুবক মানগুলোর জন্য সাধারণত কোন কীওয়ার্ড ব্যবহৃত হয়?',
    'quiz_q1_opt0': 'var',
    'quiz_q1_opt1': 'let',
    'quiz_q1_opt2': 'const',
    'quiz_q1_opt3': 'finalize',
    'quiz_q2': 'বহু ভাষায় কোন কমান্ড আউটপুট প্রিন্ট করে?',
    'quiz_q2_opt0': 'echo()',
    'quiz_q2_opt1': 'log()',
    'quiz_q2_opt2': 'print()/console.log()',
    'quiz_q2_opt3': 'writeLineForever()',
    'quiz_q3': 'কোড রক্ষণাবেক্ষণযোগ্য রাখার জন্য কী সাহায্য করে?',
    'quiz_q3_opt0': 'শুধু লম্বা ফাইল',
    'quiz_q3_opt1': 'কোনো নামকরণ নীতিমালা নেই',
    'quiz_q3_opt2': 'পুনঃব্যবহারযোগ্য ফাংশন/মডিউল',
    'quiz_q3_opt3': 'কখনো মন্তব্য নেই',
    'score_label': 'স্কোর',
    'about_tab': 'সম্পর্কে',
    'tutorials_tab': 'টিউটোরিয়াল',
    'exercises_tab': 'এক্সারসাইজ',
    'blog_details': 'ব্লগ বিবরণ',
    'login_title': 'লগইন',
    'login_button': 'লগইন',
    'login_welcome': 'স্বাগতম ফিরে',
    'login_subtitle': 'শিখতে এবং আপনার প্রোফাইল পরিচালনা করতে সাইন ইন করুন।',
    'label_email': 'ইমেইল',
    'err_email_required': 'ইমেইল প্রয়োজন',
    'err_email_invalid': 'সঠিক ইমেইল লিখুন',
    'err_password_required': 'পাসওয়ার্ড প্রয়োজন',
    'password': 'পাসওয়ার্ড',
    'confirm_password': 'পাসওয়ার্ড নিশ্চিত করুন',
    'create_account': 'অ্যাকাউন্ট তৈরি করুন',
    'signup_title': 'সাইন আপ',
    'signup_button': 'অ্যাকাউন্ট তৈরি করুন',
    'no_account': 'অ্যাকাউন্ট নেই? একটি তৈরি করুন',
    'already_account': 'ইতিমধ্যে একটি অ্যাকাউন্ট আছে? লগইন করুন',
    'certificates_title': 'সার্টিফিকেট',
    'enroll': 'নথিভুক্ত করুন',
    'admin_title': 'অ্যাডমিন',
    'admin_panel_title': 'অ্যাডমিন প্যানেল',
    'refresh': 'রিফ্রেশ করুন',
    'signup_subtitle':
        'অগ্রগতি ট্র্যাক এবং প্রোফাইল বৈশিষ্ট্য অ্যাক্সেস করতে একুশে কোডিং এ যোগদান করুন।',
    'label_name': 'নাম',
    'err_name_required': 'নাম প্রয়োজন',
    'err_min_password': 'ন্যূনতম ৮ অক্ষর',
    'err_confirm_password': 'পাসওয়ার্ড নিশ্চিত করুন',
    'err_password_mismatch': 'পাসওয়ার্ড মিলছে না',
    // App / UI
    'app_title': 'একুশে কোডিং',
    'page_home': 'হোম',
    'all_languages': 'সমস্ত ভাষা',
    'all_languages_subtitle': 'পূর্ণ ভাষা তালিকা খুলুন',
    'locale_label': 'ভাষা:',
    'views': 'বিউ',
    'label_level': 'স্তর',
    'label_duration': 'সময়কাল',
    // Theme
    'theme_light': 'লাইট মোড',
    'theme_dark': 'ডার্ক মোড',
    'theme_system': 'সিস্টেম ডিফল্ট',
    // Admin
    'admin_panel_subtitle': 'ব্লগ, টিউটোরিয়াল এবং এক্সারসাইজ পরিচালনা করুন',
  };
}
