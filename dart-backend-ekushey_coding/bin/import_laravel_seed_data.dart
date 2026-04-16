import 'dart:io';

import '../lib/src/store.dart';

Future<void> main(List<String> args) async {
  final overwrite = args.contains('--overwrite');

  final store = InMemoryStore();
  await store.initializePersistence(loadExisting: !overwrite);

  if (!store.isPersistenceEnabled) {
    stderr.writeln(
      store.persistenceStatus ??
          'PostgreSQL is not configured. Set DATABASE_URL first.',
    );
    exit(1);
  }

  if (!overwrite) {
    stdout.writeln(
      'Import skipped because loadExisting=true and existing DB data was loaded.\n'
      'Use --overwrite to force one-time seed import from Laravel-derived seed data.',
    );
    await store.closePersistence();
    return;
  }

  await store.persistState();
  stdout.writeln(
    'One-time Laravel seed import completed (users/blogs/tutorials/exercises/favorites/activities).',
  );
  await store.closePersistence();
}
