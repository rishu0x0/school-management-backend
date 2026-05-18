# Stack Research
## School Management App — Attendance Module

**Project:** Flutter + Go School Attendance App  
**Researched:** 2026-05-19  
**Research type:** Stack dimension (ecosystem survey)  
**Confidence note:** WebSearch and WebFetch were unavailable during this session. All findings are based on training knowledge current through ~August 2025. Version numbers are the last known stable releases; verify on pub.dev / pkg.go.dev before pinning. Confidence levels reflect this constraint honestly.

---

## Locked Stack (Not Up for Discussion)

| Layer | Technology | Notes |
|-------|-----------|-------|
| Mobile | Flutter (iOS + Android) | Dart SDK ≥3.0 required for modern patterns |
| Backend | Go (Golang) REST API | Go 1.22+ recommended |
| Database | Supabase (PostgreSQL) | Temporary for Phase 1; may migrate Phase 2+ |
| OTP | MSG91 | Template-ID based; requires account setup |
| Auth | JWT (Access + Refresh tokens) | 24h access / non-expiring refresh |
| File generation | PDF + Excel (.xlsx) server-side | Go-side generation |
| Storage | Supabase Storage | 90-day TTL on generated reports |

---

## Flutter Packages

### 1. State Management

**Recommendation: Riverpod (riverpod / flutter_riverpod / hooks_riverpod)**

| Package | Version | Confidence |
|---------|---------|-----------|
| `flutter_riverpod` | `^2.5.1` | MEDIUM |
| `riverpod_annotation` | `^2.3.5` | MEDIUM |
| `riverpod_generator` | `^2.4.0` (dev) | MEDIUM |

**Rationale:**
- Riverpod 2.x with code generation (`@riverpod` annotation) is the cleanest modern pattern as of 2025. You define providers as annotated functions; the generator emits the boilerplate.
- Flutter's own team has moved away from recommending `Provider`; Riverpod is its spiritual successor from the same author (Remi Rousselet) with compile-time safety.
- BLoC/Cubit (flutter_bloc) is battle-hardened and popular in enterprise projects but introduces significant boilerplate (Event → State → BLoC classes). For a one-developer project this overhead is unjustified.
- Provider (the package) is in maintenance mode — still works but no new patterns emerging.
- For this app: attendance swipe state (current student index, swipe history, undo stack), auth state (JWT tokens, login status), and class/student lists are all well-served by Riverpod's `AsyncNotifier` and `Notifier` patterns.

**What NOT to use:**
- `Provider` — maintenance mode, use Riverpod instead.
- `GetX` — opinionated "do everything" framework; poor separation of concerns; community has fragmented.
- `MobX` — requires heavy codegen, overkill for this scope.
- Raw `InheritedWidget` / `ChangeNotifier` — too verbose for this app size.

**Gotcha:** Riverpod 2.x requires Dart 3.0+. The `riverpod_generator` and `build_runner` setup adds a codegen step (`dart run build_runner watch`). Plan this into your dev workflow from day one — adding it mid-project is painful.

---

### 2. Navigation

**Recommendation: go_router**

| Package | Version | Confidence |
|---------|---------|-----------|
| `go_router` | `^14.x` (Google-maintained) | HIGH |

**Rationale:**
- `go_router` is the Flutter team's officially endorsed navigation package (shipped under `flutter.dev` on pub.dev). It implements the Navigator 2.0 API with a declarative route table and URL-based routing.
- For this app: the auth guard (redirect to login if no token) and deep-linking to specific class/report screens are trivially handled with `go_router`'s `redirect` callback.
- Integrates cleanly with Riverpod: watch auth state in the `redirect` parameter.
- Shell routes allow the bottom nav / side menu to persist across screen pushes.

**What NOT to use:**
- `auto_route` — more feature-rich but heavier codegen; overkill here.
- Raw `Navigator.pushNamed` — no type safety, no deep link support.
- `beamer` — less community momentum than go_router.

**Gotcha:** go_router v14+ changed some APIs from earlier versions. If you find tutorials online, check they're for v12+. The `GoRouter.redirect` function must return `null` (not navigate) if no redirect is needed — a common beginner mistake that causes infinite redirect loops.

---

### 3. HTTP Client

**Recommendation: Dio**

| Package | Version | Confidence |
|---------|---------|-----------|
| `dio` | `^5.4.3` | MEDIUM |

**Rationale:**
- `dio` supports interceptors natively, which is essential here: a JWT interceptor that auto-refreshes the access token when a 401 is received, then retries the original request. Implementing this with `http` (the base package) requires writing the queue logic yourself.
- `dio` also handles multipart forms, download progress tracking (useful for large PDF downloads), and cancelable requests.
- `http` (Dart team's package) is lighter and simpler — fine for trivial apps but the interceptor gap is decisive for this project.

**What NOT to use:**
- Raw `http` package for this app — lack of interceptors makes JWT refresh logic messy.
- `chopper` — adds codegen overhead for no real benefit here.

**Gotcha:** `dio` 5.x changed the error handling API from 4.x. `DioException` replaces `DioError`. If you copy older code samples, update these references. Also: disable `dio`'s default `LogInterceptor` in production builds — it logs request bodies including auth tokens.

---

### 4. Secure Storage (JWT Tokens)

**Recommendation: flutter_secure_storage**

| Package | Version | Confidence |
|---------|---------|-----------|
| `flutter_secure_storage` | `^9.2.2` | MEDIUM |

**Rationale:**
- The PRD explicitly requires storing JWT refresh tokens securely on device. `flutter_secure_storage` uses Keychain on iOS and Android Keystore on Android — the OS-level secure enclave. No alternative exists that provides the same level of security.
- The `^9.x` releases added Android `EncryptedSharedPreferences` support as an option and improved migration APIs.

**What NOT to use:**
- `shared_preferences` — plaintext storage, completely unsuitable for tokens.
- Custom file-based storage — replicates OS security primitives poorly.

**Gotcha:**
- **Android minSdkVersion:** `flutter_secure_storage` requires `minSdkVersion 18` at minimum; modern versions recommend 21. Since the PRD targets Android 6.0 (API 23), this is compatible — but you must set `minSdkVersion 23` in `android/app/build.gradle`.
- **Android backup:** By default, Android Auto Backup may back up the secure storage to Google Drive, defeating security. Add `android:allowBackup="false"` or configure backup rules to exclude the secure storage key-value store.
- **iOS — iCloud Keychain sync:** By default, iOS Keychain items sync across devices. For refresh tokens that are device-specific (per-device sessions as the PRD requires), set `IOSOptions` with `accessibility: KeychainAccessibility.first_unlock_this_device_only` to prevent cross-device sync.

---

### 5. Swipe Card Widget

**Recommendation: Build a custom implementation using Flutter's GestureDetector + AnimationController**

**Rationale:**
- Existing packages (`appinio_swiper`, `flutter_card_swiper`, `swipeable_cards`) are either unmaintained, have limited customization, or introduce constraints on card content.
- The PRD requires: colored overlays (green/red/yellow) appearing progressively as the card is dragged, smooth 60fps physics, an Undo stack, and three distinct swipe directions (left, right, up). These specific requirements make a custom implementation cleaner than bending a library to fit.
- A custom implementation using `Draggable`, `Transform.rotate`, `Opacity`/`ColorFiltered`, and `AnimationController` with a spring physics curve gives full control over the feel.
- Estimated effort: 2–3 days for a polished custom swipe widget. This is worth it over fighting a library that doesn't quite fit.

**If you prefer a library:**

| Package | Version | Confidence |
|---------|---------|-----------|
| `appinio_swiper` | `^2.0.0` | LOW |
| `flutter_card_swiper` | `^7.0.0` | LOW |

**Gotcha:** Custom swipe implementation must handle the "peek" effect (next card slightly visible below the top card) using a `Stack` with offset transforms. The undo animation (card flying back to center) requires storing the card's exit direction.

---

### 6. PDF Viewer (Flutter side)

**Recommendation: flutter_pdfview (or syncfusion_flutter_pdfviewer)**

| Package | Version | Confidence |
|---------|---------|-----------|
| `flutter_pdfview` | `^1.3.2` | MEDIUM |
| `syncfusion_flutter_pdfviewer` | `^26.x` | MEDIUM |

**Rationale:**
- The PRD generates PDFs server-side and returns a download URL. The Flutter app needs to display them in-app.
- `flutter_pdfview` wraps native PDF renderers (PDFKit on iOS, PdfRenderer on Android) — lightweight and no license cost.
- `syncfusion_flutter_pdfviewer` is more feature-rich (text selection, bookmarks, search) but requires a Syncfusion community license (free for revenue <$1M/year, but you must register).
- For Phase 1 (just viewing the generated report before downloading), `flutter_pdfview` is sufficient.

**Alternative approach:** Open the PDF URL in the device's default PDF app via `url_launcher`. This is the simplest approach and avoids in-app rendering complexity for Phase 1.

| Package | Version | Confidence |
|---------|---------|-----------|
| `url_launcher` | `^6.3.0` | HIGH |

**Recommendation for Phase 1:** Use `url_launcher` to open the Supabase Storage URL in the native PDF viewer. Add in-app PDF viewing in Phase 2 if needed.

---

### 7. Charts (Statistics Screen)

**Recommendation: fl_chart**

| Package | Version | Confidence |
|---------|---------|-----------|
| `fl_chart` | `^0.69.0` | MEDIUM |

**Rationale:**
- The statistics screen requires a donut/pie chart showing Present/Absent/Leave breakdown.
- `fl_chart` is the most popular Flutter charting library, fully Flutter-native (no WebView), supports donut charts, bar charts, and line charts — covers the statistics screen requirements.
- `syncfusion_flutter_charts` is more feature-rich but heavier and requires the Syncfusion license.

---

### 8. Other Flutter Utilities

| Package | Version | Purpose | Confidence |
|---------|---------|---------|-----------|
| `freezed` | `^2.5.2` | Immutable data classes for models (attendance record, teacher, class, etc.) | MEDIUM |
| `freezed_annotation` | `^2.4.1` | Annotation companion to freezed | MEDIUM |
| `json_serializable` | `^6.8.0` | JSON encode/decode code generation | MEDIUM |
| `json_annotation` | `^4.9.0` | Annotation companion to json_serializable | MEDIUM |
| `build_runner` | `^2.4.9` (dev) | Runs all code generators (riverpod, freezed, json_serializable) | MEDIUM |
| `intl` | `^0.19.0` | Date formatting (Indian date formats, month names for reports) | HIGH |
| `cached_network_image` | `^3.3.1` | Student photo display with cache | MEDIUM |
| `shimmer` | `^3.0.0` | Loading skeleton UI for class/student lists | MEDIUM |
| `connectivity_plus` | `^6.0.3` | Detect network state for the "no internet" screen | MEDIUM |

**Note on codegen packages:** `freezed`, `json_serializable`, and `riverpod_generator` all run through `build_runner`. Run a single `dart run build_runner build --delete-conflicting-outputs` to regenerate all at once. Set up a VS Code task or Makefile target for this.

---

## Go (Backend) Packages

### 1. HTTP Router

**Recommendation: Chi**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/go-chi/chi/v5` | `v5.1.0` | MEDIUM |

**Rationale:**
- Chi is idiomatic Go — it works with the standard `net/http` interfaces (`http.Handler`, `http.HandlerFunc`). Middleware is composable and standard library compatible. No framework lock-in.
- **Gin** (`github.com/gin-gonic/gin`) is faster in benchmarks and has a larger ecosystem, but uses its own `Context` type rather than `context.Context`, creating a thin framework dependency throughout your codebase. For a small API this matters less, but Chi is easier to test and stays closer to stdlib.
- **Echo** (`github.com/labstack/echo/v4`) is similar to Gin — performant, opinionated Context, good middleware. Slightly more complex than Chi for this scope.
- **Fiber** (`github.com/gofiber/fiber/v2`) is Fasthttp-based (not `net/http` compatible) — avoid, as it breaks compatibility with standard middleware.
- For this app (a modest REST API, single developer, clean codebase priority), Chi wins on simplicity and testability.

**What NOT to use:**
- Fiber — not `net/http` compatible.
- Gorilla Mux — mostly in maintenance mode; Chi is the natural successor.

**Middleware to use with Chi:**
- `chi/middleware.Logger` — structured request logging
- `chi/middleware.Recoverer` — panic recovery
- `chi/middleware.RequestID` — request tracing
- `chi/middleware.RealIP` — get real IP behind proxy
- `chi/middleware.Compress` — gzip response compression
- Custom JWT middleware — validate Bearer token, inject teacher_id into context

---

### 2. JWT

**Recommendation: golang-jwt/jwt**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/golang-jwt/jwt/v5` | `v5.2.1` | MEDIUM |

**Rationale:**
- `golang-jwt/jwt` is the maintained fork of the original `dgrijalva/jwt-go` (which was abandoned). The v5 release improved the API with typed claims and better error handling.
- Direct competitor `lestrrat-go/jwx` is more feature-complete (JWE, JWK rotation, OIDC) but massively over-engineered for this use case. This app uses simple HS256 or RS256 tokens — `golang-jwt/jwt` v5 is the right scope.

**Token design for this app:**
```go
// Access token claims (24h TTL)
type AccessClaims struct {
    TeacherID string `json:"teacher_id"`
    jwt.RegisteredClaims
}

// Refresh tokens: stored as hashed opaque strings in DB
// NOT a JWT — just a random UUID stored in refresh_tokens table
// On /auth/refresh: look up token hash, verify it exists, issue new access JWT
```

**Important design note:** Per the PRD, refresh tokens are non-expiring and stored in a `refresh_tokens` table (one row per device session). They should NOT be JWTs — they should be opaque random strings (UUID v4 or 32-byte random hex) stored as a bcrypt hash in the DB. A JWT refresh token can't be individually revoked without a blocklist; an opaque DB-backed token can. This aligns with the PRD's "logout invalidates the specific device token" requirement.

**Confidence:** MEDIUM (version numbers from training data)

---

### 3. Password Hashing

**Recommendation: golang.org/x/crypto/bcrypt**

| Package | Version | Confidence |
|---------|---------|-----------|
| `golang.org/x/crypto` | `v0.23.0` | MEDIUM |

**Rationale:**
- The PRD mandates bcrypt at cost factor 12. This is the standard Go bcrypt implementation — no alternatives are needed.
- `golang.org/x/crypto/bcrypt` is from the official Go extended library and is the de facto standard.

**Usage:**
```go
// Hash (registration)
hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)

// Verify (login)
err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(inputPassword))
```

**Gotcha:** bcrypt at cost 12 takes ~300–400ms per operation on a typical server. This is intentional (brute-force resistance) but means login/registration are inherently slow. Do NOT run bcrypt in a tight loop (e.g., don't accidentally call it per-student during seed generation). The seed endpoint doesn't need real passwords — use a placeholder hash.

---

### 4. Database Access (Supabase / PostgreSQL)

**Recommendation: pgx v5 (direct PostgreSQL driver)**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/jackc/pgx/v5` | `v5.6.0` | MEDIUM |
| `github.com/jackc/pgx/v5/pgxpool` | (included in pgx/v5) | MEDIUM |

**Rationale:**
- Supabase is PostgreSQL. Use `pgx` (the most performant, feature-complete Go PostgreSQL driver) directly rather than going through Supabase's REST API.
- **Supabase REST API (PostgREST):** Auto-generated REST endpoints from your schema. Convenient but adds a round-trip through an HTTP layer, limits query expressiveness, and couples you to PostgREST's URL query syntax. For a Go backend that controls its own SQL, this is the wrong layer.
- **supabase-go client** (`github.com/supabase-community/supabase-go`): A thin wrapper around Supabase's REST/Realtime APIs. NOT a database driver — it hits the PostgREST HTTP API. Avoid for server-side Go; use pgx directly.
- **pgx vs database/sql + lib/pq:** `pgx` v5 is significantly faster, has native support for PostgreSQL-specific types (UUID, JSONB, arrays), prepared statement caching, and a cleaner API. Use `pgxpool` for connection pooling in the API server.

**What NOT to use:**
- `supabase-go` client in the Go backend — it's meant for client-side use (mobile/web), not server-to-server.
- `database/sql` with `lib/pq` — pgx is strictly better for Go+PostgreSQL.
- Supabase PostgREST API from Go backend — unnecessary HTTP hop.

**Supabase-specific considerations:**
- Connect via the **direct connection string** (port 5432), not the connection pooler (port 6543 / pgBouncer), for long-lived server connections with pgxpool. Use the pooler only for serverless/edge functions.
- Find your connection string in Supabase Dashboard → Project Settings → Database → Connection string.
- Use pgxpool with `MaxConns: 10` for a small API; Supabase's free tier limits connections.

**Optional ORM layer:**

If raw SQL feels verbose, consider `sqlc` (code generator, not an ORM):

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/sqlc-dev/sqlc` | `v1.26.0` (dev tool) | MEDIUM |

`sqlc` takes your SQL queries in `.sql` files and generates type-safe Go functions. You write SQL; it generates Go. This is superior to both raw `pgx` (no type safety) and an ORM like GORM (which hides SQL and generates bad queries for complex joins). Recommended for this project.

**What NOT to use:**
- `GORM` — generates N+1 queries, hides SQL, poor for complex reports. The attendance report query (pivot table of all students × all days) is exactly the kind of query GORM handles badly.

---

### 5. PDF Generation

**Recommendation: go-pdf/fpdf (gopdf) or unidoc/unipdf**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/go-pdf/fpdf` | `v2.7.0` | MEDIUM |
| `github.com/phpdave11/gofpdi` (importer, companion) | `v1.0.13` | LOW |

**Rationale:**
- `go-pdf/fpdf` is the actively maintained fork of the original `jung-kurt/gofpdf` (which was archived). It provides a straightforward API for creating PDFs with tables, text, lines, and headers/footers.
- The PRD's PDF structure (cover page + tabular data pages + summary page) maps cleanly to fpdf's page/table model.
- `unidoc/unipdf` (`github.com/unidoc/unipdf/v3`) is a commercial PDF library — more powerful but requires a license for production use ($$$). Avoid.

**Alternative: maroto**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/johnfercher/maroto/v2` | `v2.1.0` | MEDIUM |

`maroto` is a higher-level PDF library built on top of fpdf that provides a grid/column layout system — easier for structured report pages. For the attendance grid (rows = students, columns = days), maroto's table abstraction may be cleaner than raw fpdf positioning math.

**Recommendation:** Use `maroto v2` for the report generator. The grid layout maps naturally to the attendance table structure. Fall back to raw `go-pdf/fpdf` if maroto's layout model doesn't accommodate the dense date-column layout.

**Gotcha:**
- PDF table generation for 25 students × 31 days (775 cells per page) requires careful column width calculation. At A4 landscape, each day column is ~6mm wide — barely enough for a single character ("P", "A", "L"). Prototype the page layout early; adjusting cell widths after the fact is tedious.
- **Font embedding:** fpdf/maroto require fonts to be embedded for Unicode support. The default fonts only support Latin characters — fine for English-only Phase 1, but plan for font embedding if Phase 2 adds regional languages.
- **Performance:** Generating a 4-page PDF for 50 students should complete in well under 1 second. The 30-second PRD limit is very conservative — PDF generation is not the bottleneck.

---

### 6. Excel Generation

**Recommendation: excelize**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/xuri/excelize/v2` | `v2.8.1` | MEDIUM |

**Rationale:**
- `excelize` is the dominant Go Excel library (>17k GitHub stars). It supports reading and writing .xlsx files, cell styles, conditional formatting, merged cells, formula cells, and data validation.
- The PRD requires conditional formatting (Green = Present, Red = Absent, Yellow = Leave) — `excelize` supports this via `AddConditionalFormat`.
- No meaningful competitors exist in the Go ecosystem; this is the standard choice.

**Gotcha:**
- Conditional formatting in excelize requires understanding Excel's `ConditionalFormatOptions` struct — the API is not intuitive. Budget 2–3 hours for getting the color rules correct and tested.
- `excelize` is memory-efficient for large files via `StreamWriter` for sequential writes. For attendance reports (modest size), the standard API is fine.
- Always call `file.Close()` after writing; excelize uses temp files internally.

---

### 7. MSG91 Integration

**Recommendation: Raw HTTP via Go's net/http (no SDK)**

**Rationale:**
- No official or well-maintained MSG91 Go SDK exists. Community SDKs are outdated.
- MSG91's OTP API is simple (2 endpoints: send OTP, verify OTP). A direct HTTP implementation takes 30–50 lines of Go.
- Using a thin wrapper over `net/http` keeps the dependency surface clean.

**Implementation pattern:**
```go
// MSG91 OTP flow
type MSG91Client struct {
    AuthKey    string
    TemplateID string
    HTTPClient *http.Client
}

// POST https://control.msg91.com/api/v5/otp
// Body: { "template_id": "...", "mobile": "91XXXXXXXXXX", "authkey": "..." }
// Response: { "type": "success", "request_id": "session_id" }

// POST https://control.msg91.com/api/v5/otp/verify
// Body: { "mobile": "91XXXXXXXXXX", "otp": "123456", "authkey": "..." }
```

**Setup complexity — IMPORTANT:**
- MSG91 requires an account, a DLT-registered template (mandatory in India for transactional OTPs since 2021), and an `authkey`.
- **DLT registration** (Distributed Ledger Technology — India's TRAI regulation for SMS/OTP): The SMS template must be registered on the DLT platform (Airtel, Vodafone, or others) before MSG91 can send it. This is a regulatory requirement, not a technical one. Registration takes 1–7 days.
- The OTP template must follow the format: "Your OTP for [App Name] is {#var#}. Valid for 10 minutes. Do not share."
- **Template ID** from DLT must be configured in your MSG91 account and passed in every API call.
- **Sender ID** (6-character alphanumeric, e.g., "SCHOOL") must also be DLT-registered.
- Budget 1 week lead time for DLT registration before you can test OTP in production.

---

### 8. Cron Job (Monthly Report Auto-Generation)

**Recommendation: robfig/cron v3**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/robfig/cron/v3` | `v3.0.1` | MEDIUM |

**Rationale:**
- The PRD requires a cron job running on the 1st of every month to generate reports for all classes.
- `robfig/cron` is the standard Go cron library. It runs in-process (no external scheduler needed for Phase 1).
- For Phase 1 (single server instance), an in-process cron is fine. Phase 2+ with horizontal scaling would need an external job queue (e.g., Supabase pg_cron extension, or a dedicated job runner).

**Gotcha:** In-process cron requires the server to be running at midnight on the 1st. If the server is restarted exactly at that moment, the job may be missed. For Phase 1 this is acceptable; for production Phase 2 use `pg_cron` in Supabase or a managed scheduler.

**Alternative:** Supabase has a `pg_cron` extension that can trigger a PostgreSQL function or call a webhook. This is more reliable for production but adds complexity in Phase 1.

---

### 9. Configuration Management

**Recommendation: github.com/joho/godotenv + os.Getenv**

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/joho/godotenv` | `v1.5.1` | MEDIUM |

Or use `github.com/caarlos0/env/v11` for struct-based config:

| Package | Version | Confidence |
|---------|---------|-----------|
| `github.com/caarlos0/env/v11` | `v11.0.0` | MEDIUM |

**Rationale:**
- Load `.env` in development, real environment variables in production (Supabase/Railway/Fly.io pass them as env vars).
- `caarlos0/env` parses env vars directly into a typed Go struct — cleaner than scattered `os.Getenv` calls.

**Config struct for this app:**
```go
type Config struct {
    DatabaseURL     string `env:"DATABASE_URL,required"`
    JWTSecret       string `env:"JWT_SECRET,required"`
    MSG91AuthKey    string `env:"MSG91_AUTH_KEY,required"`
    MSG91TemplateID string `env:"MSG91_TEMPLATE_ID,required"`
    SupabaseURL     string `env:"SUPABASE_URL,required"`
    SupabaseKey     string `env:"SUPABASE_SERVICE_KEY,required"` // service role key for Storage
    Port            string `env:"PORT" envDefault:"8080"`
}
```

---

### 10. Structured Logging

**Recommendation: log/slog (standard library, Go 1.21+)**

**Rationale:**
- Go 1.21 introduced `log/slog` as the official structured logging package. No third-party dependency needed.
- `slog` supports JSON output (for production log aggregation) and text output (for development).
- If more features are needed (sampling, rotation): `go.uber.org/zap` v1.27 is the battle-tested alternative.

**What NOT to use:**
- `logrus` — in maintenance mode; use `slog` or `zap`.
- `github.com/sirupsen/logrus` — same as above.

---

## Supabase Integration Patterns

### Go Backend ↔ Supabase

**Pattern: Direct pgx connection (not REST API)**

```
Go API Server
    └── pgxpool → PostgreSQL (Supabase, port 5432)
    └── Supabase Storage SDK (or raw HTTP) → File upload/download URLs
```

**Connection string format:**
```
postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres?sslmode=require
```

**Supabase Storage from Go:**
Use the `supabase-go` client ONLY for Supabase Storage operations (file upload, signed URL generation). This is the one case where the Supabase client adds value over raw HTTP — it handles bucket auth and signed URL generation.

```go
import "github.com/supabase-community/storage-go"

client := storage_go.NewClient(supabaseURL+"/storage/v1", serviceRoleKey, nil)
// Upload file
response, err := client.UploadFile("reports", objectPath, fileBuffer, ...)
// Get signed URL (90-day expiry)
signedURL, err := client.CreateSignedUrl("reports", objectPath, 90*24*3600)
```

---

### Row Level Security (RLS) — Design

**Requirement:** Teachers can only access their own classes, students, and attendance records.

**Approach:**

1. The Go API server connects to Supabase using the **service role key** (bypasses RLS) — this is correct because the Go API enforces its own authorization (JWT middleware validates teacher_id, all queries are scoped by teacher_id in WHERE clauses).

2. RLS is a secondary defense layer: set up policies that also enforce ownership. This way, even if the Go API has a bug that forgets to scope by teacher_id, RLS rejects the query at the DB level.

**RLS Policy pattern:**
```sql
-- Enable RLS on all tables
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

-- Create a policy for each table
-- NOTE: When using service role key from Go, RLS is bypassed.
-- These policies apply to direct Supabase client access (dashboard, anon key).
CREATE POLICY "teacher_owns_class" ON classes
    USING (teacher_id = auth.uid());

-- For Go backend (service role): enforce scoping in SQL WHERE clauses
-- e.g.: SELECT * FROM classes WHERE teacher_id = $1
```

**Recommended approach for Phase 1:**
- Use **service role key** in the Go backend.
- Enforce ALL authorization in the Go middleware and SQL WHERE clauses.
- Enable RLS as defense-in-depth but do not rely on it as the primary auth mechanism from Go.
- Do NOT expose Supabase anon key or direct DB access to the Flutter app — all access goes through the Go API.

**Gotcha:** If you ever use the Supabase anon key from the Flutter app (not recommended), RLS policies become critical. But since all traffic flows through the Go API with the service role key, RLS is defense-in-depth only.

---

## Not Recommended / Explicitly Avoid

| Category | Avoid | Reason |
|----------|-------|--------|
| Flutter state mgmt | Provider, GetX | Maintenance mode / poor separation |
| Flutter state mgmt | MobX | Heavy codegen, complex for this scope |
| Flutter nav | auto_route | Codegen overhead not justified |
| Flutter HTTP | chopper | Codegen not worth it for simple API |
| Flutter token storage | shared_preferences | Plaintext — completely unsafe |
| Go router | Fiber | Not net/http compatible |
| Go router | gorilla/mux | Maintenance mode |
| Go ORM | GORM | Hides SQL, generates bad queries for reports |
| Go PDF | unipdf | Commercial license required |
| Go DB | supabase-go as DB driver | It's a REST client, not a DB driver |
| Go DB | GORM + Supabase | Double abstraction over PostgreSQL |
| Go DB | database/sql + lib/pq | pgx is strictly better |
| Go JWT | lestrrat-go/jwx | Massively over-engineered for HS256/RS256 |
| Go logging | logrus | Maintenance mode; use slog |
| Supabase | PostgREST from Go | Unnecessary HTTP layer over direct pgx |

---

## Summary Dependency Lists

### Flutter pubspec.yaml (dependencies)
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.0.0

  # HTTP client
  dio: ^5.4.3

  # Secure storage
  flutter_secure_storage: ^9.2.2

  # Data models
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

  # Charts
  fl_chart: ^0.69.0

  # Utilities
  intl: ^0.19.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  connectivity_plus: ^6.0.3
  url_launcher: ^6.3.0  # for opening PDFs in native viewer

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  freezed: ^2.5.2
  json_serializable: ^6.8.0
```

### Go go.mod (key dependencies)
```go
require (
    github.com/go-chi/chi/v5           v5.1.0
    github.com/golang-jwt/jwt/v5       v5.2.1
    github.com/jackc/pgx/v5            v5.6.0
    github.com/xuri/excelize/v2        v2.8.1
    github.com/johnfercher/maroto/v2   v2.1.0
    github.com/robfig/cron/v3          v3.0.1
    github.com/joho/godotenv           v1.5.1
    github.com/caarlos0/env/v11        v11.0.0
    github.com/supabase-community/storage-go  v0.7.0
    golang.org/x/crypto                v0.23.0
)
```

---

## Setup Complexity Warnings

| Item | Complexity | Lead Time | Notes |
|------|-----------|-----------|-------|
| MSG91 DLT registration | HIGH | 1–7 days | Required for OTP in India; can't be done programmatically |
| MSG91 template approval | MEDIUM | 1–3 days | Template must match DLT-registered format exactly |
| Supabase RLS policies | MEDIUM | 0 | Write during schema setup; easy to forget and debug later |
| Flutter build_runner setup | MEDIUM | 1 hour | `dart run build_runner build` must run after every model change |
| pgx + SSL (Supabase) | LOW | 30 min | Must pass `sslmode=require` in connection string |
| go_router redirect loops | LOW | 1–2 hours | Common mistake; test auth guard thoroughly |
| dio JWT interceptor | MEDIUM | 2–4 hours | Token refresh with request queue (avoid double-refresh race) |
| excelize conditional formatting | MEDIUM | 2–3 hours | API is non-obvious; test with real Excel and Google Sheets |
| PDF column layout (dense) | HIGH | 3–5 hours | 31 columns × 25 rows on A4 landscape; needs careful sizing |
| flutter_secure_storage iOS Keychain | LOW | 1 hour | Configure `KeychainAccessibility` for per-device tokens |

---

## Confidence Summary

| Area | Confidence | Notes |
|------|-----------|-------|
| Flutter state management (Riverpod) | MEDIUM | Strong community consensus as of mid-2025; no web verification possible this session |
| Flutter navigation (go_router) | HIGH | Official Flutter team package; well-established |
| Flutter HTTP (dio) | MEDIUM | Dominant choice; version number may be slightly stale |
| Flutter secure storage | MEDIUM | Only viable option for this use case |
| Go router (chi) | MEDIUM | Well-established; Gin is equally valid choice |
| Go JWT (golang-jwt/jwt v5) | MEDIUM | Maintained fork; v5 is the current major |
| Go database (pgx v5) | MEDIUM | Standard choice for Go + PostgreSQL |
| Go Excel (excelize) | HIGH | Dominant; no real competitor |
| Go PDF (maroto v2) | MEDIUM | Newer library; fpdf is fallback if maroto proves limiting |
| MSG91 integration | MEDIUM | API docs pattern known; DLT requirement is India-specific fact |
| Supabase RLS patterns | MEDIUM | Standard PostgreSQL RLS; Supabase docs follow pg conventions |
| sqlc recommendation | MEDIUM | Growing adoption; strong fit for this use case |

---

## Sources

*Note: Web sources were unavailable this session (WebSearch and WebFetch permissions not granted). All findings are based on training knowledge current through ~August 2025. The following are the authoritative sources to verify before pinning versions:*

- Flutter packages: https://pub.dev/
- Go packages: https://pkg.go.dev/
- Riverpod docs: https://riverpod.dev/
- go_router docs: https://pub.dev/documentation/go_router/latest/
- go-chi/chi: https://github.com/go-chi/chi
- golang-jwt/jwt: https://github.com/golang-jwt/jwt
- pgx v5: https://github.com/jackc/pgx
- excelize: https://xuri.me/excelize/en/
- maroto: https://github.com/johnfercher/maroto
- MSG91 OTP API: https://docs.msg91.com/reference/send-otp
- Supabase Go client: https://github.com/supabase-community/supabase-go
- sqlc: https://docs.sqlc.dev/
- Supabase RLS: https://supabase.com/docs/guides/database/row-level-security
