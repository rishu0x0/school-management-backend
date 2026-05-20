# 07-03 Summary: Storage, Cron, Migration

## What was built
- `supabase/migrations/20260520000005_reports.sql` — reports table DDL + RLS policy
- `backend/internal/reports/storage_service.go` — StorageClient: Upload, SignedURL, deleteObject
- `backend/internal/reports/service.go` — ReportService: CreateReportRow, GenerateReport, ListReports, DeleteExpired
- `backend/internal/reports/cron.go` — StartCron: monthly (35 18 1 * * UTC) + daily cleanup

## Key decisions
- Cron: `35 18 1 * *` UTC = 00:05 IST on 1st of every month
- Worker pool: max 10 concurrent with semaphore channel
- Signed URLs valid 7 days; auto-refreshed on ListReports
- `time.Date(now.Year(), now.Month()-1, 1, ...)` for safe previous-month calculation

## Build status
`go build ./internal/reports/...` — zero errors
