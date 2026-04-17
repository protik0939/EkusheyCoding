import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../store.dart';
import 'context.dart';
import 'router.dart';

Future<void> runServer(InMemoryStore store) async {
  await store.initializePersistence();
  if (store.isPersistenceEnabled) {
    print(store.persistenceStatus);
  } else {
    stderr.writeln(store.persistenceStatus);
  }

  final api = ApiContext(store);
  final router = buildApiRouter(api);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(api.persistStateMiddleware())
      .addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    int.parse(Platform.environment['PORT'] ?? '8080'),
  );

  print(
    'Dart backend listening on http://${server.address.host}:${server.port}',
  );
  print('Health endpoint: http://localhost:${server.port}/api/health');
  print('Default admin: admin@ekusheycoding.com / admin123');

  ProcessSignal.sigint.watch().listen((_) async {
    await store.closePersistence();
    exit(0);
  });
}
