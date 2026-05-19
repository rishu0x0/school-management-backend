package auth

import (
	"net/http"

	jwtpkg "school-management/backend/pkg/jwt"
)

// JWTMiddleware is a stub for Plan 02-02.
// Full implementation (token extraction, claims injection, 401 on missing/invalid token) is in Plan 02-03.
func JWTMiddleware(jwtSvc *jwtpkg.Service) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Full implementation in 02-03
			next.ServeHTTP(w, r)
		})
	}
}
