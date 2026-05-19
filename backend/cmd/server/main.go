package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/joho/godotenv"
	"school-management/backend/internal/attendance"
	"school-management/backend/internal/auth"
	"school-management/backend/internal/classes"
	"school-management/backend/internal/config"
	"school-management/backend/internal/db"
	"school-management/backend/internal/msg91"
	"school-management/backend/internal/stats"
	"school-management/backend/internal/students"
	jwtpkg "school-management/backend/pkg/jwt"
)

func main() {
	_ = godotenv.Load()

	cfg := config.Load()
	pool := db.NewPool(cfg.DatabaseURL)
	defer pool.Close()

	jwtSvc := jwtpkg.New(cfg.JWTSecret, cfg.JWTAccessExpiry)
	msg91Client := msg91.New(cfg.MSG91AuthToken, cfg.MSG91WidgetID)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	authSvc := auth.NewService(pool, jwtSvc, msg91Client)
	authHandler := auth.NewHandler(authSvc)

	classSvc := classes.NewService(pool)
	classHandler := classes.NewHandler(classSvc)

	studentSvc := students.NewService(pool)
	studentHandler := students.NewHandler(studentSvc)

	attendanceSvc := attendance.NewService(pool)
	attendanceHandler := attendance.NewHandler(attendanceSvc)

	statsSvc := stats.NewService(pool)
	statsHandler := stats.NewHandler(statsSvc)

	r.Route("/auth", func(r chi.Router) {
		r.Post("/register/send-otp", authHandler.SendRegistrationOTP)
		r.Post("/register/verify-otp", authHandler.VerifyRegistrationOTP)
		r.Post("/otp/retry", authHandler.RetryOTP)
		r.Post("/login", authHandler.Login)
		r.Post("/refresh", authHandler.Refresh)
		r.Group(func(r chi.Router) {
			r.Use(auth.JWTMiddleware(jwtSvc))
			r.Post("/logout", authHandler.Logout)
		})
	})

	// Protected routes — JWT required for all endpoints below
	r.Group(func(r chi.Router) {
		r.Use(auth.JWTMiddleware(jwtSvc))

		// Classes CRUD
		r.Get("/classes", classHandler.List)
		r.Post("/classes", classHandler.Create)
		r.Put("/classes/{classID}", classHandler.Update)
		r.Delete("/classes/{classID}", classHandler.Delete)

		// Students CRUD (plan 03-02)
		r.Get("/classes/{classID}/students", studentHandler.List)
		r.Post("/classes/{classID}/students", studentHandler.Create)
		r.Put("/classes/{classID}/students/{studentID}", studentHandler.Update)
		r.Delete("/classes/{classID}/students/{studentID}", studentHandler.SoftRemove)
		r.Post("/classes/{classID}/students/seed", studentHandler.Seed)

		// Attendance (plan 03-03)
		r.Get("/classes/{classID}/attendance", attendanceHandler.GetByDate)
		r.Post("/classes/{classID}/attendance", attendanceHandler.SubmitBatch)
		r.Put("/classes/{classID}/attendance/{sessionID}", attendanceHandler.EditRecords)

		// Stats (plan 03-04)
		r.Get("/classes/{classID}/stats/today", statsHandler.Today)
		r.Get("/classes/{classID}/stats/monthly", statsHandler.Monthly)
	})

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("server starting on :%s (env=%s)", cfg.Port, cfg.Env)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("graceful shutdown failed: %v", err)
	}
	log.Println("server stopped")
}
