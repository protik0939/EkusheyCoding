import '../lib/src/server/server.dart';
import '../lib/src/store.dart';

Future<void> main(List<String> args) async {
  final store = InMemoryStore();
  await runServer(store);
}
