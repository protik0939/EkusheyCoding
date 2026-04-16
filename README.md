# Ekushey Coding Monorepo

This repository contains two apps:

- `ekushey_coding` -> Flutter frontend (mobile/web/desktop)
- `dart-backend-ekushey_coding` -> Dart Shelf API backend

## Prerequisites

Install these first:

- Flutter SDK (stable)
- Dart SDK (comes with Flutter, or standalone for backend)
- PostgreSQL (optional, only if you want persistent DB mode)

Recommended versions:

- Dart 3.9+
- Flutter stable channel

## Project Structure

- `ekushey_coding/` Flutter client app
- `dart-backend-ekushey_coding/` API server
- `dart-backend-ekushey_coding/db/migrations/` SQL migrations

## Quick Start (After Cloning)

### 1) Start the backend

Open terminal 1:

```bash
cd dart-backend-ekushey_coding
dart pub get
dart run bin/server.dart
```

Backend runs on:

- `http://localhost:8080`
- Health check: `GET http://localhost:8080/api/health`

### 2) Start the Flutter app

Open terminal 2:

```bash
cd ekushey_coding
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
```

If you are running on web:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

## PostgreSQL Mode (Optional)

By default, backend can run without DB configuration. For persistent relational storage, use PostgreSQL.

### 1) Set DB connection string

In terminal (same terminal where backend runs):

```bash
# Linux/macOS
export DATABASE_URL="postgres://username:password@localhost:5432/w3university"

# Windows PowerShell
$env:DATABASE_URL="postgres://username:password@localhost:5432/w3university"
```

### 2) Run migration

```bash
cd dart-backend-ekushey_coding
dart run bin/migrate.dart
```

### 3) (Optional) Import Laravel-aligned seed data once

```bash
dart run bin/import_laravel_seed_data.dart --overwrite
```

### 4) Start backend

```bash
dart run bin/server.dart
```

## Default Admin Credentials

- Email: `admin@ekusheycoding.com`
- Password: `admin123`

## Useful Dev Commands

### Frontend

```bash
cd ekushey_coding
flutter analyze
flutter test
```

### Backend

```bash
cd dart-backend-ekushey_coding
dart analyze
```

## CI/CD Rules Added

This repo includes GitHub Actions workflows:

- `.github/workflows/ci.yml`
  - Runs Flutter analyze/test and backend analyze on PRs to `main` and pushes to `main`.
- `.github/workflows/auto-merge.yml`
  - For PRs targeting `main`, enables auto-merge when the PR is mergeable (no conflict).

Important repository settings to enable in GitHub:

1. Turn on **Allow auto-merge** in repository settings.
2. Protect `main` branch and require status checks.
3. Mark CI checks from `ci.yml` as required.

With those settings, PRs from feature branches will merge automatically once they are conflict-free and required checks pass.
