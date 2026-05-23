package students

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/xuri/excelize/v2"
)

// ImportResult summarises a bulk-import operation.
type ImportResult struct {
	Total   int        `json:"total"`
	Created int        `json:"created"`
	Skipped int        `json:"skipped"`
	Errors  []RowError `json:"errors,omitempty"`
}

// RowError describes a problem with a specific row.
type RowError struct {
	Row     int    `json:"row"`
	Message string `json:"message"`
}

// columnMap holds the zero-based column indices we care about.
type columnMap struct {
	name     int // required
	roll     int // required
	photoURL int // optional (-1 means not found)
}

// detectColumns inspects the first row and returns column indices.
// It matches header text case-insensitively against known aliases.
func detectColumns(headers []string) (*columnMap, error) {
	cm := &columnMap{name: -1, roll: -1, photoURL: -1}

	for i, raw := range headers {
		h := strings.TrimSpace(strings.ToLower(raw))
		switch h {
		case "full_name", "name", "student name", "student_name", "fullname":
			cm.name = i
		case "roll_number", "roll", "roll no", "roll_no", "sr no", "sr_no", "rollnumber":
			cm.roll = i
		case "photo_url", "photo", "photourl", "photo url":
			cm.photoURL = i
		}
	}

	if cm.name == -1 {
		return nil, fmt.Errorf("could not find a 'Name' / 'Full Name' / 'Student Name' column in the header row")
	}
	if cm.roll == -1 {
		return nil, fmt.Errorf("could not find a 'Roll Number' / 'Roll No' / 'Roll' / 'Sr No' column in the header row")
	}
	return cm, nil
}

// BulkImportFromExcel parses an .xlsx file and inserts students into the given class.
// Roll numbers are always read from the file — no auto-sequencing.
func (s *Service) BulkImportFromExcel(ctx context.Context, classID, teacherID string, file io.Reader) (*ImportResult, error) {
	if err := s.verifyClassOwnership(ctx, classID, teacherID); err != nil {
		return nil, err
	}

	f, err := excelize.OpenReader(file)
	if err != nil {
		return nil, fmt.Errorf("failed to open Excel file: %w", err)
	}
	defer f.Close()

	// Use the first sheet.
	sheetName := f.GetSheetName(0)
	if sheetName == "" {
		return nil, fmt.Errorf("Excel file has no sheets")
	}

	rows, err := f.GetRows(sheetName)
	if err != nil {
		return nil, fmt.Errorf("failed to read sheet %q: %w", sheetName, err)
	}
	if len(rows) < 2 {
		return nil, fmt.Errorf("Excel file must have a header row and at least one data row")
	}

	// Detect columns from the header row.
	cm, err := detectColumns(rows[0])
	if err != nil {
		return nil, err
	}

	result := ImportResult{}

	for rowIdx, row := range rows[1:] {
		excelRow := rowIdx + 2 // 1-indexed, skip header

		// Helper to safely get a cell value.
		cell := func(col int) string {
			if col < 0 || col >= len(row) {
				return ""
			}
			return strings.TrimSpace(row[col])
		}

		name := cell(cm.name)
		rollStr := cell(cm.roll)

		// Skip completely empty rows.
		if name == "" && rollStr == "" {
			continue
		}

		result.Total++

		if name == "" {
			result.Errors = append(result.Errors, RowError{
				Row:     excelRow,
				Message: "Name is empty",
			})
			result.Skipped++
			continue
		}
		if rollStr == "" {
			result.Errors = append(result.Errors, RowError{
				Row:     excelRow,
				Message: "Roll number is empty",
			})
			result.Skipped++
			continue
		}

		// Parse roll number — accept "1", "1.0", etc.
		var rollNumber int
		if _, err := fmt.Sscanf(rollStr, "%d", &rollNumber); err != nil {
			// Try parsing as float (Excel sometimes stores numbers as float text).
			var rollFloat float64
			if _, err2 := fmt.Sscanf(rollStr, "%f", &rollFloat); err2 != nil {
				result.Errors = append(result.Errors, RowError{
					Row:     excelRow,
					Message: fmt.Sprintf("Invalid roll number %q", rollStr),
				})
				result.Skipped++
				continue
			}
			rollNumber = int(rollFloat)
		}

		if rollNumber <= 0 {
			result.Errors = append(result.Errors, RowError{
				Row:     excelRow,
				Message: fmt.Sprintf("Roll number must be positive, got %d", rollNumber),
			})
			result.Skipped++
			continue
		}

		photoURL := nullableString(cell(cm.photoURL))

		tag, err := s.db.Exec(ctx,
			`INSERT INTO students (class_id, roll_number, full_name, photo_url)
			 VALUES ($1, $2, $3, $4)
			 ON CONFLICT (class_id, roll_number) DO NOTHING`,
			classID, rollNumber, name, photoURL,
		)
		if err != nil {
			result.Errors = append(result.Errors, RowError{
				Row:     excelRow,
				Message: fmt.Sprintf("DB error: %v", err),
			})
			result.Skipped++
			continue
		}
		if tag.RowsAffected() > 0 {
			result.Created++
		} else {
			result.Skipped++
		}
	}

	return &result, nil
}
