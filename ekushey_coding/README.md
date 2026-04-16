# Ekushey Coding Flutter App

Flutter mobile app that mirrors the w3university web application features:

- Home page with language discovery
- Tutorials listing by language
- Exercises with difficulty and language filters
- Blog listing and details
- Authentication (login/signup)
- Profile management
- Certificates page
- Admin panel for blogs, exercises, and tutorials

## Backend

Set backend URL with dart define if needed:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
```

If not provided, default API URL is:

- `http://localhost:8080/api`

## Run

```bash
flutter pub get
flutter run
```
