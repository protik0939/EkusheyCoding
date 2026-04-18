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
  };
}
