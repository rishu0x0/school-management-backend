package config

import (
	"fmt"
	"log"
	"os"
	"time"
)

// Config holds all application configuration loaded from environment variables.
// OCI deployment uses individual DB_* variables to build the DSN.
// Supabase fields are kept as optional for the storage layer only.
type Config struct {
	// ── Postgres (OCI) ──────────────────────────────────────────────────────
	// If DATABASE_URL is set it takes priority; otherwise DSN is built from parts.
	DatabaseURL string
	DBHost      string
	DBPort      string
	PGUser      string
	PGPassword  string
	PGDatabase  string

	// ── DragonflyDB ─────────────────────────────────────────────────────────
	// Address of the Dragonfly instance — private IP of the DB VM, e.g. 10.0.0.5:6379
	DragonflyAddr     string
	DragonflyPassword string

	// ── OCI Object Storage ─────────────────────────────────────────────────
	OCINamespace      string
	OCIBucketName     string
	OCIRegion         string
	// Path to the OCI config file or Instance Principal auth toggle
	OCIConfigFile     string // e.g. ~/.oci/config
	OCIUseInstancePrincipal bool // set OCI_USE_INSTANCE_PRINCIPAL=true on the VM

	// ── JWT ──────────────────────────────────────────────────────────────────
	JWTSecret       string
	JWTAccessExpiry time.Duration

	// ── Server ───────────────────────────────────────────────────────────────
	Port string
	Env  string

	// ── MSG91 ────────────────────────────────────────────────────────────────
	MSG91AuthToken string
	MSG91WidgetID  string

	// ── Supabase (legacy — storage only, now migrated to OCI) ───────────────
	// Kept in struct for backward-compat during cutover; not required at start.
	SupabaseURL            string
	SupabaseServiceRoleKey string
}

func Load() *Config {
	cfg := &Config{
		// Postgres
		DBHost:     getEnv("DB_HOST", "10.0.0.5"),
		DBPort:     getEnv("DB_PORT", "5432"),
		PGUser:     getEnv("PG_USER", "postgres"),
		PGPassword: getEnv("PG_PASSWORD", ""),
		PGDatabase: getEnv("PG_DATABASE", "schoolmgmt"),

		// DragonflyDB — defaults to the private IP of the co-located DB VM
		DragonflyAddr:     getEnv("DRAGONFLY_ADDR", "10.0.0.5:6379"),
		DragonflyPassword: getEnv("DRAGONFLY_PASSWORD", ""),

		// OCI Object Storage
		OCINamespace:            getEnv("OCI_NAMESPACE", ""),
		OCIBucketName:           getEnv("OCI_BUCKET_NAME", "reports"),
		OCIRegion:               getEnv("OCI_REGION", "ap-mumbai-1"),
		OCIConfigFile:           getEnv("OCI_CONFIG_FILE", ""),
		OCIUseInstancePrincipal: getEnv("OCI_USE_INSTANCE_PRINCIPAL", "false") == "true",

		// JWT
		JWTSecret: requireEnv("JWT_SECRET"),
		Port:      getEnv("PORT", "8080"),
		Env:       getEnv("ENV", "development"),

		// MSG91
		MSG91AuthToken: requireEnv("MSG91_AUTH_TOKEN"),
		MSG91WidgetID:  requireEnv("MSG91_WIDGET_ID"),

		// Supabase (optional during cutover)
		SupabaseURL:            getEnv("SUPABASE_URL", ""),
		SupabaseServiceRoleKey: getEnv("SUPABASE_SERVICE_ROLE_KEY", ""),
	}

	// Build DATABASE_URL from parts if not explicitly set
	if url := os.Getenv("DATABASE_URL"); url != "" {
		cfg.DatabaseURL = url
	} else {
		if cfg.PGPassword == "" {
			log.Fatal("PG_PASSWORD (or DATABASE_URL) is required but not set")
		}
		cfg.DatabaseURL = fmt.Sprintf(
			"postgresql://%s:%s@%s:%s/%s",
			cfg.PGUser, cfg.PGPassword, cfg.DBHost, cfg.DBPort, cfg.PGDatabase,
		)
	}

	expiryStr := getEnv("JWT_ACCESS_EXPIRY", "24h")
	d, err := time.ParseDuration(expiryStr)
	if err != nil {
		log.Fatalf("invalid JWT_ACCESS_EXPIRY %q: %v", expiryStr, err)
	}
	cfg.JWTAccessExpiry = d

	return cfg
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("required env var %s is not set", key)
	}
	return v
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
