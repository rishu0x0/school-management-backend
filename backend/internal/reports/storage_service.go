package reports

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const reportsBucket = "reports"

// StorageClient wraps Supabase Storage REST calls.
type StorageClient struct {
	baseURL        string
	serviceRoleKey string
	httpClient     *http.Client
}

func NewStorageClient(supabaseURL, serviceRoleKey string) *StorageClient {
	return &StorageClient{
		baseURL:        supabaseURL,
		serviceRoleKey: serviceRoleKey,
		httpClient:     &http.Client{Timeout: 60 * time.Second},
	}
}

// Upload uploads bytes to the reports bucket at storagePath.
func (s *StorageClient) Upload(storagePath string, data []byte, contentType string) error {
	url := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.baseURL, reportsBucket, storagePath)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("storage upload request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.serviceRoleKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true")

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

// SignedURL generates a signed download URL valid for expiresIn seconds.
func (s *StorageClient) SignedURL(storagePath string, expiresIn int) (string, time.Time, error) {
	url := fmt.Sprintf("%s/storage/v1/object/sign/%s/%s", s.baseURL, reportsBucket, storagePath)
	body, _ := json.Marshal(map[string]int{"expiresIn": expiresIn})

	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("signed url request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.serviceRoleKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("signed url: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		rb, _ := io.ReadAll(resp.Body)
		return "", time.Time{}, fmt.Errorf("signed url status %d: %s", resp.StatusCode, rb)
	}

	var result struct {
		SignedURL string `json:"signedURL"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", time.Time{}, fmt.Errorf("signed url decode: %w", err)
	}

	signedURL := result.SignedURL
	if len(signedURL) > 0 && signedURL[0] == '/' {
		signedURL = s.baseURL + signedURL
	}

	expiresAt := time.Now().Add(time.Duration(expiresIn) * time.Second)
	return signedURL, expiresAt, nil
}

// deleteObject sends a DELETE to Supabase Storage (best-effort, used for cleanup).
func (s *StorageClient) deleteObject(storagePath string) error {
	url := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.baseURL, reportsBucket, storagePath)
	req, err := http.NewRequest(http.MethodDelete, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+s.serviceRoleKey)
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}
