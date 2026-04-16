# Dart Backend For W3University

This folder contains a Dart Shelf backend that mirrors the Laravel API structure from backend-w3university.

## What It Includes

- Public routes for auth, blogs, tutorials, and exercises
- Protected routes for user profile, favorites, activity, and performance
- Admin routes for blog/exercise/tutorial management and stats
- Bearer token auth and admin-role checks
- Seeded in-memory data based on the original project content

## Run

```bash
dart pub get
dart run bin/server.dart
```

## PostgreSQL Persistence

The backend now supports persistent storage through PostgreSQL. If a connection
string is provided, all in-memory collections are loaded from PostgreSQL on
startup and persisted back after write operations.

Storage now uses relational tables:

- users
- blogs
- tutorials
- exercises
- favorites
- activities
- auth_tokens

Each table includes indexes for common query/filter paths.

Set one of these environment variables before running:

- `DATABASE_URL`
- `POSTGRES_CONNECTION_STRING`

Or create a local `.env` file in this folder (see `.env.example`) with one of
those keys.

Connection string format:

`postgres://username:password@localhost:5432/w3university`

If no connection string is provided, the server falls back to in-memory mode.

## Run Relational Migration

```bash
dart run bin/migrate.dart
```

This applies:

- db/migrations/001_create_relational_tables.sql

## One-Time Laravel Data Import

The current backend seed data is Laravel-derived (aligned with the original
backend seeders). To import it once into PostgreSQL:

```bash
dart run bin/import_laravel_seed_data.dart --overwrite
```

Without `--overwrite`, the script preserves existing DB data.

Server default URL: `http://localhost:8080`

Health endpoint:

- `GET /api/health`

## Default Admin

- Email: `admin@ekusheycoding.com`
- Password: `admin123`

## Notes

- Data is in-memory and resets when the server restarts.
- API base path is `/api` to match the frontend contracts.
