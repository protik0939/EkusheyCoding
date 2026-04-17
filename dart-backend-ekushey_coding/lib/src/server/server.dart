import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../store.dart';
import 'context.dart';
import 'router.dart';

bool isAddressInUse(SocketException error) {
  final code = error.osError?.errorCode;
  if (code == 10048 || code == 98) {
    return true;
  }

  final message = error.message.toLowerCase();
  return message.contains('address already in use') ||
      message.contains('only one usage of each socket address');
}

Future<HttpServer> serveWithPortFallback(
  Handler handler,
  InternetAddress address,
  int preferredPort, {
  int maxPortRetries = 20,
}) async {
  for (var attempt = 0; attempt < maxPortRetries; attempt++) {
    final port = preferredPort + attempt;
    try {
      if (attempt > 0) {
        print('Port ${port - 1} is busy, retrying on port $port...');
      }
      return await shelf_io.serve(handler, address, port);
    } on SocketException catch (e) {
      if (!isAddressInUse(e) || attempt == maxPortRetries - 1) {
        rethrow;
      }
    }
  }

  throw StateError('Could not start server on any fallback port.');
}

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

  final preferredPort =
      int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  final server = await serveWithPortFallback(
    handler,
    InternetAddress.anyIPv4,
    preferredPort,
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
