# Architecture Patterns

**Domain:** Mobile-first school attendance system (Flutter + Go + Supabase)
**Researched:** 2026-05-19
**Confidence:** HIGH (standard patterns, well-documented stacks)

---

## Recommended Architecture

```
┌─────────────────────────────────────────────────┐
│                   Flutter App                   │
│  ┌──────────┐  ┌────────────┐  ┌─────────────┐  │
│  │  Auth    │  │ Attendance │  │   Reports   │  │
│  │ Feature  │  │  Feature   │  │   Feature   │  │
│  └────┬─────┘  └─────┬──────┘  └──────┬──────┘  │
│       │              │                │          │
│  ┌────▼──────────────▼────────────────▼──────┐  │
│  │          Core / Shared Layer               │  │
│  │  (API client, auth state, secure storage) │  │
│  └───────────────────┬───────────────────────┘  │
└──────────────────────┼──────────────────────────┘
                       │ HTTPS / JWT
┌──────────────────────▼──────────────────────────┐
│                Go REST API                       │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Auth    │  │ Attendance│  │   Reports     │  │
│  │ Handler  │  │ Handler  │  │   Handler     │  │
│  └────┬─────┘  └────┬──────┘  └───────┬───────┘  │
│       │             │                 │           │
│  ┌────▼─────────────▼─────────────────▼──────┐   │
│  │              Service Layer                 │   │
│  │  (business logic, token mgmt, file gen)   │   │
│  └────────────────────┬───────────────────────┘  │
│                       │                          │
│  ┌────────────────────▼───────────────────────┐  │
│  │              Cron Scheduler                 │  │
│  │       (goroutine, runs in same process)    │  │
│  └────────────────────┬───────────────────────┘  │
└───────────────────────┼──────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼───────┐             ┌─────────▼──────┐
│  Supabase DB  │             │Supabase Storage│
│  PostgreSQL   │             │(PDFs / Excels) │
│  + RLS        │             │ Private bucket │
└───────────────┘             └────────────────┘
        │
┌───────▼───────┐
│    MSG91      │
│  OTP Service  │
└───────────────┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| Flutter Auth Feature | Registration form, OTP screen, login screen, secure token storage, auth guard | Go API `/auth/*`, Flutter Secure Storage |
| Flutter Attendance Feature | Swipe session state, undo stack, summary screen, submit | Go API `/attendance/*`, `/classes/*` |
| Flutter Reports Feature | Month picker, trigger generation, display download URL | Go API `/reports/*` |
| Flutter Core/Shared | Dio HTTP client, JWT interceptor, token refresh logic, routing (go_router) | All features |
| Go Auth Handler | Validate credentials, call MSG91, issue/revoke JWTs and refresh tokens | MSG91 API, Supabase DB (teachers, refresh_tokens) |
| Go Attendance Handler | CRUD for sessions + records, enforce midnight lock | Supabase DB (attendance_sessions, attendance_records) |
| Go Reports Handler | Trigger PDF/Excel generation, write to Supabase Storage, return signed URL | Supabase DB, Supabase Storage, PDF/Excel libs |
| Go Cron Scheduler | On 1st of month: query prior-month classes, trigger report generation for each | Go Reports service (internal function call) |
| Supabase PostgreSQL + RLS | Persists all data, enforces row-level access policies | Go API (service role key bypasses RLS) |
| Supabase Storage | Stores generated files in private bucket, issues time-limited signed URLs | Go API (service role key) |
| MSG91 | Sends OTP via SMS, holds session state, verifies OTP | Go Auth Handler |

---

## Data Flow

### Auth Flow (Registration)
```
Flutter → POST /auth/send-otp { mobile }
  → Go checks DB for duplicate mobile
  → Go calls MSG91 Send OTP → returns session_id
  → Flutter stores session_id in memory

Flutter → POST /auth/verify-otp { session_id, otp }
  → Go calls MSG91 Verify → success

Flutter → POST /auth/register { name, mobile, school, password, session_id }
  → Go creates teacher row (bcrypt password)
  → Go creates refresh_token row
  → Returns { access_token, refresh_token }
  → Flutter stores both in Secure Storage → navigates to Home
```

### Auth Flow (Subsequent Launches)
```
Flutter App Opens
  → Read refresh_token from Secure Storage
  → If found: POST /auth/refresh → new access_token
    → Success: navigate to Home (no login screen shown)
    → 401 returned: navigate to Login, clear Secure Storage
  → If not found: navigate to Login
```

### Attendance Submission Flow
```
Flutter loads students for class → GET /classes/:id/students
  → Teacher swipes cards (all state held in Flutter memory, no partial saves)
  → Undo operates on in-memory stack only (no API calls)
  → Teacher taps Submit

Flutter → POST /attendance/submit
  { class_id, date, records: [{student_id, status}, ...] }
  → Go API:
    1. Verifies JWT, extracts teacher_id
    2. Checks class belongs to teacher (ownership check)
    3. Checks no session exists for class+date (upsert logic)
    4. Checks not past midnight (lock check)
    5. Upserts attendance_session, bulk-inserts attendance_records
    6. Returns session summary

Flutter → navigates to Statistics Screen
```

### Attendance Edit Flow
```
Flutter → PATCH /attendance/:session_id
  { records: [{student_id, status}, ...] }
  → Go API:
    1. Verifies JWT
    2. Verifies session.teacher_id == requesting teacher
    3. Checks session.date == today (same-day rule)
    4. Checks current time < midnight (lock check)
    5. Updates records
```

### Report Generation Flow (Manual)
```
Flutter → POST /classes/:id/reports/generate { month, type }
  → Go API:
    1. Queries attendance_sessions + records for class + month
    2. Generates PDF (gofpdf) or Excel (excelize) in memory
    3. Uploads file to Supabase Storage (private bucket)
    4. Inserts row into generated_reports table
    5. Returns signed URL (time-limited, ~1 hour)
Flutter → opens/downloads URL
```

### Cron Flow (Automatic Monthly Reports)
```
1st of Month, 00:05 AM (cron goroutine fires):
  → Query: SELECT DISTINCT class_id FROM attendance_sessions
      WHERE date >= first_of_previous_month AND date < first_of_this_month
  → For each class_id:
      → Call same report generation function as manual export
      → Store file in Supabase Storage
      → Insert row into generated_reports
      → (Phase 2) Trigger in-app notification
```

---

## 1. Flutter App Architecture

### Feature-First Folder Structure (Recommended)

Use **feature-first** with a shared core layer. Feature-first is the right choice because:
- Each feature (auth, classes, attendance, reports) is independently deployable in future phases
- Teams can work on features without stomping on each other's directories
- State, widgets, and data sources for a feature live together — easier to reason about

```
lib/
  core/
    api/              # Dio client, interceptors, base repository
    auth/             # AuthState, token storage wrapper
    router/           # go_router config, auth guard redirect logic
    widgets/          # Shared widgets (loading, error states)
    utils/            # Date helpers, formatters
  features/
    auth/
      data/           # AuthRepository, AuthRemoteDataSource
      domain/         # Teacher model, AuthFailure types
      presentation/   # RegistrationPage, LoginPage, OtpPage
    classes/
      data/
      domain/
      presentation/   # ClassListPage, ClassDetailPage
    students/
      data/
      domain/
      presentation/
    attendance/
      data/           # AttendanceRepository
      domain/         # AttendanceSession model, SwipeState
      presentation/
        swipe/        # SwipeScreen, StudentCard, SwipeController
        summary/      # SummaryScreen
        stats/        # StatisticsScreen
    reports/
      data/
      domain/
      presentation/   # ReportScreen, MonthPicker
  main.dart
```

### Auth Guard / Route Protection

Use **go_router with redirect** — the standard Flutter navigation approach:

```dart
// core/router/app_router.dart
final router = GoRouter(
  redirect: (context, state) {
    final isAuthenticated = ref.read(authStateProvider).isAuthenticated;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');

    if (!isAuthenticated && !isAuthRoute) return '/auth/login';
    if (isAuthenticated && isAuthRoute) return '/home';
    return null;
  },
  routes: [...],
);
```

The `authStateProvider` (Riverpod) holds auth state initialized at app start:
1. App launches → `main.dart` triggers `authStateProvider` initialization
2. Provider reads refresh token from Secure Storage
3. If found → calls `/auth/refresh` → sets authenticated state
4. GoRouter's redirect reacts to auth state change → navigates automatically

**No explicit splash screen routing needed** — go_router redirect handles it. A simple loading widget while the auth check runs is sufficient.

### State Management for Attendance Session

Use **Riverpod StateNotifier** for the attendance swipe session:

```dart
// features/attendance/domain/swipe_session_state.dart
class SwipeSessionState {
  final List<StudentCard> remaining;    // students not yet swiped
  final List<AttendanceRecord> decided; // swiped students with status
  final StudentCard? lastDecided;       // for undo
  final AttendanceStatus? lastStatus;   // for undo
}

class SwipeSessionNotifier extends StateNotifier<SwipeSessionState> {
  void swipe(AttendanceStatus status) {
    // pop from remaining, push to decided, record last for undo
  }

  void undo() {
    // pop from decided, push back to remaining top
    // ONE level only: clear lastDecided after undo
  }
}
```

Key design decisions:
- **All state is in-memory until submit** — no partial API calls during swiping (matches PRD "offline" requirement during session)
- **Single-level undo** — `lastDecided` holds exactly one entry; after undo it's cleared
- **Summary screen reads from the same state** — `decided` list is the source of truth for summary edits
- **Submit** sends the full `decided` list as one POST call

---

## 2. Go Backend Structure

### Single-Process Monolith (Recommended)

Build a **single Go binary** — a monolith with clean internal package separation. Do NOT split into microservices for Phase 1. Rationale:
- One service to deploy, one process to debug
- Cron runs as a goroutine in the same process — no separate scheduler service
- All business logic in one codebase — faster iteration
- Supabase is already handling infrastructure concerns (DB, storage)

```
cmd/
  server/
    main.go           # Entry point, starts HTTP server + cron scheduler
internal/
  auth/
    handler.go        # HTTP handlers
    service.go        # Business logic
    repository.go     # DB queries
  classes/
    handler.go
    service.go
    repository.go
  students/
    handler.go
    service.go
    repository.go
  attendance/
    handler.go
    service.go
    repository.go
    lock_checker.go   # Midnight lock logic
  reports/
    handler.go
    service.go        # Orchestrates PDF/Excel generation
    generator/
      pdf.go          # gofpdf generation
      excel.go        # excelize generation
    storage.go        # Supabase Storage upload helper
  scheduler/
    cron.go           # Monthly report cron job (goroutine)
  middleware/
    auth.go           # JWT validation middleware
    ownership.go      # Resource ownership check helpers
  db/
    client.go         # pgx connection pool setup
    migrations/       # SQL migration files
  config/
    config.go         # ENV var loading
pkg/
  msg91/
    client.go         # MSG91 API wrapper
```

### Cron Job: Goroutine in Same Process (Recommended)

Run the monthly report generation as a **goroutine using a cron library** (e.g., `robfig/cron`), not as a separate service or Supabase scheduled function.

Rationale:
- Simple to implement — no additional infrastructure
- Shares the same DB connection pool and service layer as the HTTP handlers
- `robfig/cron` is the standard Go cron library (`github.com/robfig/cron/v3`)
- Supabase scheduled functions (pg_cron) would require pushing report generation logic into the database layer — wrong separation of concerns for a Go-heavy backend

```go
// internal/scheduler/cron.go
func StartMonthlyReportScheduler(reportSvc *reports.Service) {
    c := cron.New(cron.WithLocation(time.UTC))
    // Runs at 00:05 on the 1st of every month
    c.AddFunc("5 0 1 * *", func() {
        ctx := context.Background()
        if err := reportSvc.GeneratePreviousMonthReports(ctx); err != nil {
            slog.Error("monthly report generation failed", "err", err)
        }
    })
    c.Start()
}
```

Resilience note: If the server is down on the 1st, the job does not run. For Phase 1 this is acceptable. Phase 2 can add a "catch-up on startup" check: on boot, query `generated_reports` to see if last month's reports were generated; if not and it's still the 1st, run them.

---

## 3. Supabase RLS Policies

**Architecture note:** The Go API connects using the **service role key** (bypasses RLS). The RLS policies serve as a defense-in-depth layer — they protect against direct Supabase client access and SQL injection scenarios. All business-logic access control is ALSO enforced in the Go service layer.

### Enable RLS on all tables first:
```sql
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
```

### RLS Policies

**classes — teacher sees only their own:**
```sql
CREATE POLICY "teacher_owns_class" ON classes
  FOR ALL
  USING (teacher_id = auth.uid());
```

**students — teacher sees students in their classes:**
```sql
CREATE POLICY "teacher_owns_students" ON students
  FOR ALL
  USING (
    class_id IN (
      SELECT id FROM classes WHERE teacher_id = auth.uid()
    )
  );
```

**attendance_sessions — teacher sees sessions for their classes:**
```sql
CREATE POLICY "teacher_owns_sessions" ON attendance_sessions
  FOR ALL
  USING (teacher_id = auth.uid());
```

**attendance_records — teacher sees records for their sessions:**
```sql
CREATE POLICY "teacher_owns_records" ON attendance_records
  FOR ALL
  USING (
    session_id IN (
      SELECT id FROM attendance_sessions WHERE teacher_id = auth.uid()
    )
  );
```

**generated_reports — teacher sees their own reports:**
```sql
CREATE POLICY "teacher_owns_reports" ON generated_reports
  FOR ALL
  USING (teacher_id = auth.uid());
```

**refresh_tokens — only the owning teacher:**
```sql
CREATE POLICY "teacher_owns_refresh_tokens" ON refresh_tokens
  FOR ALL
  USING (teacher_id = auth.uid());
```

**Implementation note:** Since the Go API uses the service role key, these RLS policies will not be evaluated on API-initiated queries. Their value is: (1) future direct Supabase SDK access, (2) Supabase Studio access control, (3) defense-in-depth if the service key is ever rotated to an anon key by mistake. The Go service layer is the primary enforcement point.

---

## 4. File Storage Pattern

### Use a Private Bucket (Required)

All generated PDFs and Excel files must be stored in a **private Supabase Storage bucket** (not public). Rationale:
- Report files contain student PII (names, attendance data)
- Public bucket URLs never expire — any person with the URL can access files forever
- Private bucket requires a signed URL, which expires

### Storage Structure
```
bucket: school-reports (private)
path:   {teacher_id}/{class_id}/{YYYY-MM}/{filename}

Example:
  abc-123/def-456/2026-04/GreenvalleyHS_Class5A_Attendance_2026-04.pdf
```

Teacher-ID-prefixed paths mean RLS bucket policies can be written using `storage.foldername()` matching.

### Signed URL Flow
```go
// Go API after uploading file:
signedURL, err := storageClient.CreateSignedURL(
    "school-reports",
    filePath,
    3600, // 1 hour expiry for the download link returned to client
)
// Store the Supabase Storage path (not the signed URL) in generated_reports.file_url
// Generate a fresh signed URL each time GET /reports/:id/download is called
```

**Store the storage path, not the signed URL.** Signed URLs expire; paths do not. Regenerate a signed URL on each download request.

### 90-Day Retention
Implement retention via a **Go cron job** (can run alongside the monthly report job):
```go
// On 1st of month, also clean expired reports:
// DELETE FROM generated_reports WHERE expires_at < NOW()
// AND also delete from Supabase Storage using the file_url path
```

Supabase Storage does not natively support TTL-based auto-deletion. The Go cron is the right place to handle cleanup.

---

## 5. Midnight Lock Mechanism

### Enforce at BOTH API layer AND DB layer (Recommended)

**Primary enforcement: API middleware/service layer (Go)**

The API is the correct primary enforcement point because:
- It has access to the request timestamp
- It can return a meaningful error message to the client
- It prevents the round-trip to the database

```go
// internal/attendance/lock_checker.go
func IsLocked(sessionDate time.Time) bool {
    now := time.Now()
    // Lock at midnight of the session date (in the server's timezone)
    // Server should run in UTC; client should send dates in local time
    lockTime := time.Date(
        sessionDate.Year(), sessionDate.Month(), sessionDate.Day()+1,
        0, 0, 0, 0, sessionDate.Location(),
    )
    return now.After(lockTime)
}
```

Applied in the attendance PATCH handler before any DB call.

**Secondary enforcement: DB trigger (defense-in-depth)**

Add a PostgreSQL trigger that prevents updates to locked sessions:

```sql
CREATE OR REPLACE FUNCTION enforce_attendance_lock()
RETURNS TRIGGER AS $$
BEGIN
  -- Lock at midnight: date + 1 day at 00:00:00 UTC
  IF OLD.is_locked = TRUE THEN
    RAISE EXCEPTION 'attendance_locked: Attendance for this date is locked.';
  END IF;
  -- Auto-lock if current time is past midnight of the session date
  IF NOW() > (OLD.date + INTERVAL '1 day') THEN
    RAISE EXCEPTION 'attendance_locked: Attendance for this date is locked.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER attendance_record_lock_check
  BEFORE UPDATE ON attendance_records
  FOR EACH ROW EXECUTE FUNCTION enforce_attendance_lock();
```

Also add a trigger on `attendance_sessions` to prevent updates to locked sessions.

**Why both layers?**
- API layer: Fast rejection, good error messages, stops before DB round-trip
- DB trigger: Protects against bugs in service layer, direct DB access, future Go code that skips the lock check

**Timezone handling (critical):** The attendance date is a `DATE` (no time). "Midnight" = the start of the next calendar day. Use UTC throughout the Go server. If teachers are in IST (UTC+5:30), midnight IST = 18:30 UTC. Decide server timezone in Phase 1 and document it. Recommendation: store dates in UTC, compare using `date::timestamp + interval '1 day'` in triggers.

---

## 6. Suggested Build Order

Build order respects hard dependencies — each phase unblocks the next.

### Phase 1: Database + Backend Foundation
**Must be first — everything depends on this.**
- Set up Supabase project, run schema migrations
- Enable RLS, write all policies
- Go project scaffold: config, DB client (pgx), middleware skeleton
- Auth endpoints (register, OTP, login, refresh, logout)
- JWT middleware
- `refresh_tokens` table management

**Unblocks:** All other backend and Flutter work

### Phase 2: Core CRUD API
**Build before Flutter feature work.**
- Class endpoints (CRUD)
- Student endpoints (CRUD + seed)
- Unit tests for ownership checks

**Unblocks:** Flutter class/student management, attendance endpoints

### Phase 3: Attendance API
**Depends on Phase 2 (sessions need classes and students).**
- Attendance submit endpoint (bulk insert)
- Attendance edit endpoint (with lock check)
- Stats endpoint (aggregation query)
- Midnight lock enforcement (API + DB trigger)

**Unblocks:** Flutter attendance feature

### Phase 4: Flutter Auth + Navigation Shell
**Can start in parallel with Phase 2 using mocked API.**
- go_router setup with auth guard
- AuthStateNotifier + Riverpod providers
- Registration, OTP, Login screens
- Secure Storage integration
- Silent token refresh on launch

**Unblocks:** All other Flutter screens (routing shell must exist)

### Phase 5: Flutter Class + Student Management
**Depends on Phase 4 (auth) + Phase 2 (API).**
- Class list, create, edit, delete screens
- Student list, add, edit, delete, seed screens

**Unblocks:** Flutter attendance flow (needs class selection)

### Phase 6: Flutter Attendance Swipe Feature
**The core feature — build after all prerequisites.**
- SwipeSessionNotifier with undo stack
- StudentCard widget + swipe gestures (flutter_card_swiper or custom)
- Tap button alternative
- Summary screen with inline edit
- Submit + confirm dialog
- Statistics screen

**Unblocks:** Full end-to-end attendance flow

### Phase 7: Reports (Backend + Flutter)
**Can be built independently after Phase 3.**
- Go: PDF generation (gofpdf), Excel generation (excelize)
- Go: Supabase Storage upload helper
- Go: Reports CRUD endpoints + signed URL generation
- Flutter: Report screen, month picker, download trigger
- Go: Cron scheduler (monthly auto-generation)
- 90-day cleanup job

### Phase 8: Integration + QA
- End-to-end testing
- Performance validation (swipe 60fps, API < 500ms)
- Security review (RLS spot-check, JWT rotation)
- App Store / Play Store build configuration

---

## Patterns to Follow

### Pattern 1: Repository Pattern in Go
**What:** Each feature has its own `repository.go` that owns all SQL queries. Handlers call services; services call repositories.
**When:** All DB access.
Keeps SQL out of handlers, makes unit testing with mock repositories straightforward.

### Pattern 2: Bulk Insert for Attendance Records
**What:** Use a single `INSERT ... VALUES ($1,$2), ($3,$4), ...` for all records in a session, not N individual inserts.
**When:** POST /attendance/submit
A class with 50 students = 50 records. One bulk insert is faster and atomic.

### Pattern 3: Ownership Middleware Helper
**What:** After JWT validation, add a reusable helper `CheckClassOwnership(teacherID, classID)` called at the start of every handler that touches class data.
**When:** All class/student/attendance handlers.
Centralizes the "does this teacher own this class?" check.

### Pattern 4: Idempotent Report Generation
**What:** Before generating a report, check if one already exists for `(class_id, month, file_type)`. If yes, return the existing record.
**When:** Both manual and cron-triggered generation.
Prevents duplicate files when the cron runs twice (e.g., server restart on the 1st).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Partial Attendance Saves During Swipe
**What:** Saving each swipe result to the API immediately as the teacher swipes.
**Why bad:** Network latency during swiping breaks the 60fps animation; partial records in DB create complex recovery logic; PRD states attendance is held in local state during session.
**Instead:** Hold all state in Flutter memory; submit as one atomic batch on "Submit" tap.

### Anti-Pattern 2: Public Storage Bucket
**What:** Generating report files and storing them in a public Supabase Storage bucket.
**Why bad:** Files contain student PII. Anyone with the URL can download indefinitely. URLs never expire.
**Instead:** Private bucket + signed URLs generated per download request.

### Anti-Pattern 3: Storing Signed URLs in `generated_reports.file_url`
**What:** Storing the signed URL returned by Supabase Storage in the DB.
**Why bad:** Signed URLs expire (e.g., 1 hour). Next day the stored URL is dead.
**Instead:** Store the storage path (e.g., `{teacher_id}/{class_id}/...filename`). Generate a fresh signed URL each time the download endpoint is called.

### Anti-Pattern 4: Client-Side Midnight Lock Check Only
**What:** Only checking the lock condition in Flutter.
**Why bad:** Client clocks can be manipulated. Any API client bypasses the lock.
**Instead:** Enforce lock server-side (API + DB trigger). Client-side check is only for UX (graying out the Edit button).

### Anti-Pattern 5: Polling for Report Generation Status
**What:** Flutter polls `GET /reports/:id` every 2 seconds waiting for the file to be ready.
**Why bad:** Unnecessary API load; complex client state machine.
**Instead:** PDF/Excel generation is synchronous in the Go handler (PRD allows up to 30 seconds). The POST request waits and returns the result. Show a loading indicator in Flutter. If generation takes > 30s, return 408 and let the user retry.

### Anti-Pattern 6: One Attendance Insert Per Student in a Loop
**What:** Go service loops through students and executes `INSERT INTO attendance_records` one at a time.
**Why bad:** 50 students = 50 DB round-trips; slow and non-atomic.
**Instead:** Bulk insert all records in a single query.

---

## Scalability Considerations

| Concern | Phase 1 (hundreds of teachers) | Phase 2+ (thousands of teachers) |
|---------|--------------------------------|-----------------------------------|
| DB queries | Simple indexed queries, pgx pool | Add read replicas, query optimization |
| Report generation | Synchronous in handler | Move to async job queue (Redis/BullMQ) |
| Cron job | Single goroutine, sequential | Fan out with worker pool, add distributed lock |
| Storage costs | Supabase Storage (free tier) | Consider S3-compatible migration |
| Auth tokens | Single DB table lookup per request | Add Redis token cache |
| File serving | Signed URL per request | CDN in front of storage bucket |

---

## Architectural Risks (Decide Early)

| Risk | Impact | Decision Needed |
|------|--------|----------------|
| **Timezone for midnight lock** | If server is UTC and teachers are IST, "midnight lock" = 18:30 UTC. Records from 18:30-23:59 IST would be locked while teacher thinks they're unlocked. | Choose: server runs in IST, or lock is calculated client-side from date component only |
| **Synchronous report generation** | 50 students × 30 days PDF takes 5-15 seconds. If server generates synchronously, HTTP timeout is a risk. | Pre-test generation time. If > 10s, use async with polling or webhook. |
| **Cron job resilience** | If server restarts on the 1st of the month, monthly reports won't auto-generate. | Implement catch-up check on server startup in Phase 1 or accept the risk. |
| **Supabase service key in Go API** | Service key bypasses RLS — if leaked, attacker gets full DB access. | Store in environment variable only; never commit; rotate immediately if leaked. |
| **Non-expiring refresh tokens** | A stolen refresh token grants permanent access until logout. | Mitigate: store token hashes (not plaintext) in DB; consider device fingerprint binding in Phase 2. |

---

## Sources

- Go monolith + cron patterns: `github.com/robfig/cron/v3` documentation (HIGH confidence)
- Flutter feature-first structure: flutter.dev/docs/development/data-and-backend/state-mgmt (HIGH confidence)
- Supabase RLS policies: supabase.com/docs/guides/database/row-level-security (HIGH confidence)
- Supabase Storage signed URLs: supabase.com/docs/guides/storage/serving/signed-urls (HIGH confidence)
- go_router auth redirect: pub.dev/packages/go_router (HIGH confidence)
- Riverpod StateNotifier: riverpod.dev/docs (HIGH confidence)
