# 07-05 Summary: Flutter Reports Screen

## What was built
- `app/lib/features/reports/repository/reports_repository.dart` — ReportsRepository + ReportModel
- `app/lib/features/reports/notifier/reports_notifier.dart` — ReportsNotifier (AsyncNotifier)
- `app/lib/features/reports/screens/reports_screen.dart` — full reports UI
- `/reports` route added to router.dart
- Reports icon button added to ClassListScreen AppBar

## Features
- Class selector (uses classesNotifierProvider) + month dropdown (last 6 months)
- PDF and Excel generate buttons with loading indicator
- Report list with status chips and download button (url_launcher opens signed URL)
- Refresh button in AppBar

## Build status
`flutter analyze` — no issues found
