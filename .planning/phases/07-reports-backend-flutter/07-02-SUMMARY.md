# 07-02 Summary: Excel Generation Service

## What was built
- `backend/internal/reports/excel_service.go` — `GenerateExcel(ReportData) ([]byte, error)` using excelize v2

## Key decisions
- `f.GetSheetIndex()` returns `(int, error)` in excelize v2.10.1 (plan assumed single return)
- Two sheets: "Attendance Data" (name/roll/day columns with P/A/L/— cells) and "Summary" (per-student totals)
- Green/red/amber cell fills for P/A/L; red font for students below 75%

## Build status
`go build ./internal/reports/...` — zero errors
