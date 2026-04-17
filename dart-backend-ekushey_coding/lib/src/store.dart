library store;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

part 'store/store_auth_profile.dart';
part 'store/store_persistence.dart';
part 'store/store_seed.dart';

class InMemoryStore {
  InMemoryStore() {
    _seedStore(this);
  }

  final Random _random = Random.secure();

  final List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> blogs = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> exercises = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> tutorials = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> favorites = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> activities = <Map<String, dynamic>>[];

  final Map<String, int> tokenToUserId = <String, int>{};

  int _userId = 1;
  int _blogId = 1;
  int _exerciseId = 1;
  int _tutorialId = 1;
  int _favoriteId = 1;
  int _activityId = 1;

  Connection? _db;
  bool _isPersistenceEnabled = false;
  String? _persistenceStatus;

  bool get isPersistenceEnabled => _isPersistenceEnabled;
  String? get persistenceStatus => _persistenceStatus;

  int nextBlogId() => _blogId++;
  int nextExerciseId() => _exerciseId++;
  int nextTutorialId() => _tutorialId++;
  int nextFavoriteId() => _favoriteId++;
  int nextActivityId() => _activityId++;

  static const List<String> _tokenChars = <String>[
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
}
