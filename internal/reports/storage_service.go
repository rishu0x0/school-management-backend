// Package reports — OCI Object Storage backend for generated report files.
//
// Authentication strategy (chosen at startup via config):
//   - Instance Principal (recommended for OCI VMs): no key file needed;
//     the VM's instance identity is used automatically.
//   - Config file (local dev / CI): reads ~/.oci/config or OCI_CONFIG_FILE.
//
// The StorageClient satisfies the same Upload / SignedURL / deleteObject surface
// that the rest of the reports package uses, so service.go is unchanged.
package reports

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/url"
	"os"
)

// ociConfigFile holds the minimal fields we need from ~/.oci/config.
type ociConfigFile struct {
	tenancy     string
	user        string
	fingerprint string
	privateKey  string // PEM content
	region      string
}

// StorageClient uploads/downloads report files from OCI Object Storage.
type StorageClient struct {
	namespace  string
	bucket     string
	region     string
	httpClient *http.Client

	// auth — exactly one is non-nil
	keyAuth            *ociKeyAuth            // config-file / API-key auth
	instancePrincipal  bool                   // use IMDSv2 token from metadata endpoint
}

// ociKeyAuth holds the parsed credentials for API-key-based request signing.
type ociKeyAuth struct {
	tenancy     string
	user        string
	fingerprint string
	privateKey  []byte
}

// NewStorageClient constructs a StorageClient using either Instance Principal
// (when useInstancePrincipal=true) or config-file auth.
//
// Parameters:
//   namespace            — OCI tenancy namespace (OCI_NAMESPACE)
//   bucket               — bucket name (OCI_BUCKET_NAME)
//   region               — OCI region identifier (OCI_REGION)
//   configFile           — path to OCI config file; empty string → use default ~/.oci/config
//   useInstancePrincipal — prefer instance-metadata auth (set true on production OCI VMs)
func NewStorageClient(namespace, bucket, region, configFile string, useInstancePrincipal bool) *StorageClient {
	sc := &StorageClient{
		namespace:         namespace,
		bucket:            bucket,
		region:            region,
		httpClient:        &http.Client{Timeout: 60 * time.Second},
		instancePrincipal: useInstancePrincipal,
	}

	if !useInstancePrincipal {
		// Fall back to API-key auth from config file
		if configFile == "" {
			configFile = expandHome("~/.oci/config")
		} else {
			configFile = expandHome(configFile)
		}
		ka, err := parseOCIConfig(configFile)
		if err != nil {
			// Non-fatal: StorageClient still created; uploads will fail with a clear error.
			fmt.Printf("[storage] WARNING: cannot parse OCI config %q: %v\n", configFile, err)
		} else {
			sc.keyAuth = ka
		}
	}
	return sc
}

// objectURL returns the OCI Object Storage endpoint for a given object path.
func (s *StorageClient) objectURL(storagePath string) string {
	return fmt.Sprintf(
		"https://objectstorage.%s.oraclecloud.com/n/%s/b/%s/o/%s",
		s.region, s.namespace, s.bucket,
		url.PathEscape(storagePath),
	)
}

// Upload stores fileBytes at storagePath inside the configured bucket.
func (s *StorageClient) Upload(storagePath string, data []byte, contentType string) error {
	req, err := http.NewRequest(http.MethodPut, s.objectURL(storagePath), bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("storage upload request: %w", err)
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))

	if err := s.signRequest(req); err != nil {
		return fmt.Errorf("storage sign: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("storage upload: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("storage upload status %d: %s", resp.StatusCode, body)
	}
	return nil
}

// SignedURL generates a pre-authenticated request (PAR) URL for download,
// valid for expiresIn seconds.
func (s *StorageClient) SignedURL(storagePath string, expiresIn int) (string, time.Time, error) {
	expiresAt := time.Now().UTC().Add(time.Duration(expiresIn) * time.Second)

	// Create a PAR via the OCI Object Storage PAR API
	parEndpoint := fmt.Sprintf(
		"https://objectstorage.%s.oraclecloud.com/n/%s/b/%s/p/",
		s.region, s.namespace, s.bucket,
	)

	body, _ := json.Marshal(map[string]any{
		"accessType":        "ObjectRead",
		"name":              "report-download-" + storagePath,
		"objectName":        storagePath,
		"timeExpires":       expiresAt.Format(time.RFC3339),
	})

	req, err := http.NewRequest(http.MethodPost, parEndpoint, bytes.NewReader(body))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("par request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	if err := s.signRequest(req); err != nil {
		return "", time.Time{}, fmt.Errorf("par sign: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("par create: %w", err)
	}
	defer resp.Body.Close()

	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", time.Time{}, fmt.Errorf("par create status %d: %s", resp.StatusCode, rb)
	}

	var result struct {
		AccessURI string `json:"accessUri"`
	}
	if err := json.Unmarshal(rb, &result); err != nil || result.AccessURI == "" {
		return "", time.Time{}, fmt.Errorf("par decode: %s", rb)
	}

	// OCI returns a relative URI — prefix with the Object Storage base URL
	signedURL := fmt.Sprintf("https://objectstorage.%s.oraclecloud.com%s", s.region, result.AccessURI)
	return signedURL, expiresAt, nil
}

// deleteObject deletes storagePath from the bucket (best-effort, used during cleanup).
func (s *StorageClient) deleteObject(storagePath string) error {
	req, err := http.NewRequest(http.MethodDelete, s.objectURL(storagePath), nil)
	if err != nil {
		return err
	}
	if err := s.signRequest(req); err != nil {
		return err
	}
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Request signing
// ─────────────────────────────────────────────────────────────────────────────

// signRequest attaches OCI HTTP Signature auth headers (or Instance Principal
// bearer token) to req before it is sent.
func (s *StorageClient) signRequest(req *http.Request) error {
	if s.instancePrincipal {
		return s.signWithInstancePrincipal(req)
	}
	if s.keyAuth == nil {
		return fmt.Errorf("no OCI auth configured: set OCI_CONFIG_FILE or OCI_USE_INSTANCE_PRINCIPAL=true")
	}
	return s.signWithAPIKey(req)
}

// signWithInstancePrincipal fetches a short-lived token from the OCI IMDS
// (Instance Metadata Service) and attaches it as a Bearer token.
func (s *StorageClient) signWithInstancePrincipal(req *http.Request) error {
	// OCI IMDSv2 token endpoint
	const metadataURL = "http://169.254.169.254/opc/v2/identity/token"
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	mReq, _ := http.NewRequestWithContext(ctx, http.MethodGet, metadataURL, nil)
	mReq.Header.Set("Authorization", "Bearer Oracle")
	resp, err := s.httpClient.Do(mReq)
	if err != nil {
		return fmt.Errorf("imds token fetch: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("imds token status %d: %s", resp.StatusCode, body)
	}

	// body is a raw JWT string
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(string(body)))
	return nil
}

// signWithAPIKey implements OCI HTTP Signature v1 signing for config-file auth.
func (s *StorageClient) signWithAPIKey(req *http.Request) error {
	ka := s.keyAuth
	date := time.Now().UTC().Format(http.TimeFormat)
	req.Header.Set("Date", date)

	// Signing string components
	signingString := fmt.Sprintf(
		"date: %s\n(request-target): %s %s\nhost: %s",
		date,
		strings.ToLower(req.Method),
		req.URL.RequestURI(),
		req.URL.Host,
	)

	// HMAC-SHA256 with the private key
	mac := hmac.New(sha256.New, ka.privateKey)
	mac.Write([]byte(signingString))
	sig := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	keyID := fmt.Sprintf("%s/%s/%s", ka.tenancy, ka.user, ka.fingerprint)
	req.Header.Set("Authorization", fmt.Sprintf(
		`Signature version="1",headers="date (request-target) host",keyId=%q,algorithm="hmac-sha256",signature=%q`,
		keyID, sig,
	))
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// OCI config file parsing
// ─────────────────────────────────────────────────────────────────────────────

func parseOCIConfig(path string) (*ociKeyAuth, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read OCI config: %w", err)
	}
	cfg := &ociKeyAuth{}
	var keyFile string
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "[") || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		k, v := strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
		switch k {
		case "tenancy":
			cfg.tenancy = v
		case "user":
			cfg.user = v
		case "fingerprint":
			cfg.fingerprint = v
		case "key_file":
			keyFile = expandHome(v)
		}
	}
	if keyFile != "" {
		pk, err := os.ReadFile(keyFile)
		if err != nil {
			return nil, fmt.Errorf("read OCI private key %q: %w", keyFile, err)
		}
		cfg.privateKey = pk
	}
	return cfg, nil
}

func expandHome(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return home + path[1:]
	}
	return path
}
