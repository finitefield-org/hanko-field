package firestoretest

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os/exec"
	"strings"
	"testing"
	"time"

	pconfig "github.com/hanko-field/api/internal/platform/config"
)

const firestoreEmulatorImage = "gcr.io/google.com/cloudsdktool/cloud-sdk:emulators"

// StartEmulator spins up a Firestore emulator in Docker for use within tests.
// Tests are skipped automatically when Docker is unavailable or running in -short mode.
func StartEmulator(t *testing.T, projectID string) (pconfig.FirestoreConfig, func()) {
	t.Helper()

	if testing.Short() {
		t.Skip("firestore emulator skipped in short mode")
	}

	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker binary not available: " + err.Error())
	}

	ensureDockerDaemon(t)

	if projectID == "" {
		projectID = fmt.Sprintf("test-%d", time.Now().UnixNano())
	}

	port := freePort(t)
	endpoint := fmt.Sprintf("127.0.0.1:%d", port)
	containerID := startFirestoreEmulator(t, port)

	waitForEndpoint(t, endpoint, 30*time.Second)

	cfg := pconfig.FirestoreConfig{
		ProjectID:    projectID,
		EmulatorHost: endpoint,
	}

	cleanup := func() {
		stopContainer(containerID)
	}

	t.Cleanup(cleanup)

	return cfg, cleanup
}

func ensureDockerDaemon(t *testing.T) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "docker", "info")
	if err := cmd.Run(); err != nil {
		t.Skip("docker daemon unavailable: " + err.Error())
	}
}

func freePort(t *testing.T) int {
	t.Helper()
	addr, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to allocate port: %v", err)
	}
	defer addr.Close()

	tcpAddr, ok := addr.Addr().(*net.TCPAddr)
	if !ok {
		t.Fatalf("unexpected addr type %T", addr.Addr())
	}
	return tcpAddr.Port
}

func startFirestoreEmulator(t *testing.T, port int) string {
	t.Helper()
	args := []string{
		"run", "-d", "--rm",
		"-p", fmt.Sprintf("%d:8080", port),
		firestoreEmulatorImage,
		"gcloud", "beta", "emulators", "firestore", "start",
		"--host-port=0.0.0.0:8080",
		"--quiet",
	}

	cmd := exec.Command("docker", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("start firestore emulator: %v - %s", err, strings.TrimSpace(string(out)))
	}

	id := strings.TrimSpace(string(out))
	if id == "" {
		t.Fatalf("docker returned empty container id")
	}
	if len(id) > 12 {
		id = id[:12]
	}
	return id
}

func stopContainer(id string) {
	if id == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = exec.CommandContext(ctx, "docker", "stop", id).Run()
}

func waitForEndpoint(t *testing.T, endpoint string, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	var lastErr error

	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", endpoint, 500*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return
		}
		lastErr = err
		time.Sleep(250 * time.Millisecond)
	}

	if lastErr == nil {
		lastErr = errors.New("timeout waiting for endpoint")
	}
	t.Fatalf("firestore emulator at %s not ready: %v", endpoint, lastErr)
}
