-- Relational PostgreSQL schema for dart-backend-w3university
-- Mirrors key Laravel entities with indexed query paths.

CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  password_hash TEXT NOT NULL,
  api_token_hash TEXT,
  username TEXT UNIQUE,
  skill_level TEXT,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE TABLE IF NOT EXISTS auth_tokens (
  token TEXT PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT,
  last_used_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user_id ON auth_tokens(user_id);

CREATE TABLE IF NOT EXISTS blogs (
  id BIGINT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  title_bn TEXT,
  author TEXT,
  author_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  category TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  views BIGINT NOT NULL DEFAULT 0,
  published_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_blogs_status_published ON blogs(status, published_at);
CREATE INDEX IF NOT EXISTS idx_blogs_category ON blogs(category);
CREATE INDEX IF NOT EXISTS idx_blogs_views ON blogs(views);

CREATE TABLE IF NOT EXISTS tutorials (
  id BIGINT PRIMARY KEY,
  language_id TEXT NOT NULL,
  title TEXT NOT NULL,
  tutorial_order INTEGER NOT NULL DEFAULT 0,
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_tutorials_lang_pub_order ON tutorials(language_id, is_published, tutorial_order);

CREATE TABLE IF NOT EXISTS exercises (
  id BIGINT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  title_bn TEXT,
  difficulty TEXT,
  category TEXT,
  language_id TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  views BIGINT NOT NULL DEFAULT 0,
  completions BIGINT NOT NULL DEFAULT 0,
  published_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_exercises_status_published ON exercises(status, published_at);
CREATE INDEX IF NOT EXISTS idx_exercises_filters ON exercises(difficulty, language_id, category);
CREATE INDEX IF NOT EXISTS idx_exercises_views ON exercises(views);

CREATE TABLE IF NOT EXISTS favorites (
  id BIGINT PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  category TEXT,
  favorite_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_favorites_user_type_order ON favorites(user_id, type, favorite_order);

CREATE TABLE IF NOT EXISTS activities (
  id BIGINT PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  minutes_active INTEGER NOT NULL DEFAULT 0,
  lessons_completed INTEGER NOT NULL DEFAULT 0,
  exercises_completed INTEGER NOT NULL DEFAULT 0,
  quizzes_completed INTEGER NOT NULL DEFAULT 0,
  blogs_read INTEGER NOT NULL DEFAULT 0,
  comments_posted INTEGER NOT NULL DEFAULT 0,
  code_snippets_created INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_activities_user_created ON activities(user_id, created_at);
