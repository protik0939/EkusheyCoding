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
  };
}
