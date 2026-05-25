//go:build tools

// Package tools pins tool-only dependencies so go mod tidy retains them.
// golang-migrate is installed as a CLI (see Makefile), not imported directly.
package main

import (
	_ "github.com/golang-jwt/jwt/v5"
	_ "github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "golang.org/x/crypto/bcrypt"
)
