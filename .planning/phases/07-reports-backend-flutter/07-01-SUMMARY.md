# 07-01 Summary: PDF Generation Service

## What was built
- `backend/internal/reports/report_data.go` — shared types: `ReportData`, `StudentRow`, `AttendanceLabel`
- `backend/internal/reports/pdf_service.go` — `GeneratePDF(ReportData) ([]byte, error)` using maroto v2

## Key decisions
- maroto v2 `maroto.New()` returns `core.Maroto` interface (not `maroto.Maroto`)
- `doc.GetBytes()` returns PDF bytes; `doc.Save()` takes a file path string (not io.Writer)
- 12-grid layout: Name=3, Roll=1, up to 8 day columns per page
- Cover page, data pages (25 students/page), summary page

## Build status
`go build ./internal/reports/...` — zero errors
