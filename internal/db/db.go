package db

import (
	"context"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool creates a tuned pgxpool.Pool for the OCI Postgres instance.
//
// Pool limits (maps to the requested database/sql equivalents):
//   SetMaxOpenConns(50)       → MaxConns:         50
//   SetMaxIdleConns(25)       → MinConns:         25  (kept-alive idle connections)
//   SetConnMaxLifetime(15m)   → MaxConnLifetime:  15m
//
// The pool is safe for concurrent use; all services share this single pool instance.
func NewPool(databaseURL string) *pgxpool.Pool {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		log.Fatalf("[db] failed to parse database URL: %v", err)
	}

	// Maximum open connections — matches SetMaxOpenConns(50)
	cfg.MaxConns = 50

	// Minimum idle connections kept alive — matches SetMaxIdleConns(25)
	// pgxpool pre-dials MinConns so they are ready immediately under load.
	cfg.MinConns = 25

	// Maximum connection lifetime — matches SetConnMaxLifetime(15m)
	// Rotates stale connections and handles load-balancer idle timeouts gracefully.
	cfg.MaxConnLifetime = 15 * time.Minute

	// Maximum time a connection may remain idle before being closed.
	cfg.MaxConnIdleTime = 5 * time.Minute

	// Health-check interval — pgxpool will PING idle connections every 30s.
	cfg.HealthCheckPeriod = 30 * time.Second

	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		log.Fatalf("[db] failed to create connection pool: %v", err)
	}

	if err := pool.Ping(context.Background()); err != nil {
		log.Fatalf("[db] failed to ping database: %v", err)
	}
	log.Printf("[db] connected — pool max=%d min=%d lifetime=%s",
		cfg.MaxConns, cfg.MinConns, cfg.MaxConnLifetime)
	return pool
}
