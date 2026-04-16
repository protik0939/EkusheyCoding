import 'dart:io';

import 'package:postgres/postgres.dart';

Future<String?> _readConnectionStringFromEnv() async {
  final envValue = Platform.environment['DATABASE_URL']?.trim();
  if (envValue != null && envValue.isNotEmpty) {
    return envValue;
  }

  final alt = Platform.environment['POSTGRES_CONNECTION_STRING']?.trim();
  if (alt != null && alt.isNotEmpty) {
    return alt;
  }

  final file = File('.env');
  if (!await file.exists()) {
    return null;
  }

  final lines = await file.readAsLines();
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final index = line.indexOf('=');
    if (index <= 0) {
      continue;
    }
    final key = line.substring(0, index).trim();
    final value = line.substring(index + 1).trim();
    if ((key == 'DATABASE_URL' || key == 'POSTGRES_CONNECTION_STRING') &&
        value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

Future<Connection> _openConnectionFromUrl(String connectionString) {
  final uri = Uri.parse(connectionString);
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'postgres' && scheme != 'postgresql') {
    throw const FormatException(
      'Connection string must use postgres:// or postgresql://',
    );
  }

  final database = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .join('/');
  if (database.isEmpty) {
    throw const FormatException('Database name is missing in connection URL');
  }

  final userInfoParts = uri.userInfo.split(':');
  final username = userInfoParts.isNotEmpty && userInfoParts.first.isNotEmpty
      ? Uri.decodeComponent(userInfoParts.first)
      : null;
  final password = userInfoParts.length > 1
      ? Uri.decodeComponent(userInfoParts.sublist(1).join(':'))
      : null;

  final sslModeValue = uri.queryParameters['sslmode']?.toLowerCase();
  final sslQuery = uri.queryParameters['ssl']?.toLowerCase();
  final sslRequired =
      sslQuery == 'true' ||
      sslModeValue == 'require' ||
      sslModeValue == 'verify-ca' ||
      sslModeValue == 'verify-full';

  return Connection.open(
    Endpoint(
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(
      sslMode: sslRequired ? SslMode.require : SslMode.disable,
    ),
  );
}

Future<void> main() async {
  final connectionString = await _readConnectionStringFromEnv();
  if (connectionString == null || connectionString.isEmpty) {
    stderr.writeln(
      'Missing DATABASE_URL or POSTGRES_CONNECTION_STRING in environment/.env',
    );
    exit(1);
  }

  final sqlFile = File('db/migrations/001_create_relational_tables.sql');
  if (!await sqlFile.exists()) {
    stderr.writeln('Missing migration SQL file: ${sqlFile.path}');
    exit(1);
  }

  final sql = await sqlFile.readAsString();
  final connection = await _openConnectionFromUrl(connectionString);

  try {
    final normalized = sql
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');

    final statements = normalized
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    for (final statement in statements) {
      await connection.execute(statement);
    }
    stdout.writeln('Migration applied successfully.');
  } finally {
    await connection.close();
  }
}
