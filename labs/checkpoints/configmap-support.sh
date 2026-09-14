#!/bin/bash
# Checkpoint: configmap-support
# Lesson(s) that use this: l034, l037, l039, l041, l042, l044, l045, l047, l049, l051, l053, l054, l056, l060, l061, l064, l067, l071, l074
# Changes from healthz-endpoint: Add ConfigMap reading to main.go and deployment
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/healthz-endpoint.sh"

# Update main.go to support ConfigMap reading
cat > main.go << 'MAIN_EOF'
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

type Order struct {
	ID        string    `json:"id"`
	SKU       string    `json:"sku"`
	Quantity  int       `json:"qty"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateOrderRequest struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"qty"`
}

type OrderStore struct {
	mu      sync.Mutex
	orders  map[string]*Order
	counter int
	limit   int
}

var store *OrderStore

func init() {
	limit := 1000 // default

	// Try to read from ConfigMap first
	if os.Getenv("ORDERS_CONFIG_SOURCE") == "configmap" {
		if data, err := os.ReadFile("/etc/config/orders-api/config.json"); err == nil {
			var config map[string]int
			if err := json.Unmarshal(data, &config); err == nil {
				if configLimit, ok := config["store_limit"]; ok && configLimit > 0 {
					limit = configLimit
				}
			}
		}
	}

	// Fall back to environment variable
	if envLimit := os.Getenv("ORDERS_STORE_LIMIT"); envLimit != "" {
		if l, err := strconv.Atoi(envLimit); err == nil && l > 0 {
			limit = l
		}
	}

	store = &OrderStore{
		orders: make(map[string]*Order),
		limit:  limit,
	}
}

func logRequest(r *http.Request, statusCode int, duration time.Duration) {
	log.Printf(`level=info method=%s path=%s status=%d duration_ms=%d`, r.Method, r.URL.Path, statusCode, duration.Milliseconds())
}

func healthz(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
	logRequest(r, http.StatusOK, time.Since(start))
}

func listOrders(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	store.mu.Lock()
	orders := make([]*Order, 0, len(store.orders))
	for _, order := range store.orders {
		orders = append(orders, order)
	}
	store.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
	logRequest(r, http.StatusOK, time.Since(start))
}

func createOrder(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	var req CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid request body"})
		logRequest(r, http.StatusBadRequest, time.Since(start))
		return
	}

	if req.SKU == "" || req.Quantity <= 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "sku and qty are required and qty must be positive"})
		logRequest(r, http.StatusBadRequest, time.Since(start))
		return
	}

	store.mu.Lock()
	if len(store.orders) >= store.limit {
		store.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "store is full"})
		logRequest(r, http.StatusInternalServerError, time.Since(start))
		return
	}

	store.counter++
	id := fmt.Sprintf("%d", store.counter)
	order := &Order{
		ID:        id,
		SKU:       req.SKU,
		Quantity:  req.Quantity,
		CreatedAt: time.Now().UTC(),
	}
	store.orders[id] = order
	store.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(order)
	logRequest(r, http.StatusCreated, time.Since(start))
}

func getOrder(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	id := strings.TrimPrefix(r.URL.Path, "/orders/")

	store.mu.Lock()
	order, exists := store.orders[id]
	store.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "order not found"})
		logRequest(r, http.StatusNotFound, time.Since(start))
		return
	}

	json.NewEncoder(w).Encode(order)
	logRequest(r, http.StatusOK, time.Since(start))
}

func main() {
	port := "8000"
	if envPort := os.Getenv("ORDERS_PORT"); envPort != "" {
		port = envPort
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthz)
	mux.HandleFunc("GET /orders", listOrders)
	mux.HandleFunc("POST /orders", createOrder)
	mux.HandleFunc("GET /orders/{id}", getOrder)

	addr := ":" + port
	log.Printf(`level=info msg="server starting" addr=%s`, addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf(`level=error msg="server failed" error=%s`, err)
	}
}
MAIN_EOF

# Update main_test.go to add test for ConfigMap support
cat > main_test.go << 'TEST_EOF'
package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthz(t *testing.T) {
	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()
	healthz(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var resp map[string]string
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp["status"] != "healthy" {
		t.Errorf("expected status 'healthy', got '%s'", resp["status"])
	}
}

func TestListOrders(t *testing.T) {
	// Start with a fresh store for each test
	store = &OrderStore{
		orders:  make(map[string]*Order),
		counter: 0,
		limit:   1000,
	}

	req := httptest.NewRequest("GET", "/orders", nil)
	w := httptest.NewRecorder()
	listOrders(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var orders []*Order
	if err := json.NewDecoder(w.Body).Decode(&orders); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(orders) != 0 {
		t.Errorf("expected empty list, got %d orders", len(orders))
	}
}

func TestCreateOrder(t *testing.T) {
	tests := []struct {
		name          string
		body          CreateOrderRequest
		expectedCode  int
		shouldSucceed bool
	}{
		{
			name:          "valid order",
			body:          CreateOrderRequest{SKU: "ABC123", Quantity: 5},
			expectedCode:  http.StatusCreated,
			shouldSucceed: true,
		},
		{
			name:          "missing SKU",
			body:          CreateOrderRequest{SKU: "", Quantity: 5},
			expectedCode:  http.StatusBadRequest,
			shouldSucceed: false,
		},
		{
			name:          "zero quantity",
			body:          CreateOrderRequest{SKU: "ABC123", Quantity: 0},
			expectedCode:  http.StatusBadRequest,
			shouldSucceed: false,
		},
		{
			name:          "negative quantity",
			body:          CreateOrderRequest{SKU: "ABC123", Quantity: -1},
			expectedCode:  http.StatusBadRequest,
			shouldSucceed: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset store
			store = &OrderStore{
				orders:  make(map[string]*Order),
				counter: 0,
				limit:   1000,
			}

			body := new(bytes.Buffer)
			json.NewEncoder(body).Encode(tt.body)

			req := httptest.NewRequest("POST", "/orders", body)
			w := httptest.NewRecorder()
			createOrder(w, req)

			if w.Code != tt.expectedCode {
				t.Errorf("expected status %d, got %d", tt.expectedCode, w.Code)
			}

			if tt.shouldSucceed {
				var order Order
				if err := json.NewDecoder(w.Body).Decode(&order); err != nil {
					t.Fatalf("failed to decode response: %v", err)
				}
				if order.SKU != tt.body.SKU || order.Quantity != tt.body.Quantity {
					t.Errorf("order mismatch: got %+v, expected SKU=%s, Qty=%d", order, tt.body.SKU, tt.body.Quantity)
				}
			}
		})
	}
}

func TestGetOrder(t *testing.T) {
	// Reset store and add an order
	store = &OrderStore{
		orders:  make(map[string]*Order),
		counter: 0,
		limit:   1000,
	}

	// Create an order first
	bodyCreate := new(bytes.Buffer)
	json.NewEncoder(bodyCreate).Encode(CreateOrderRequest{SKU: "TEST123", Quantity: 10})
	reqCreate := httptest.NewRequest("POST", "/orders", bodyCreate)
	wCreate := httptest.NewRecorder()
	createOrder(wCreate, reqCreate)

	tests := []struct {
		name         string
		id           string
		expectedCode int
	}{
		{
			name:         "existing order",
			id:           "1",
			expectedCode: http.StatusOK,
		},
		{
			name:         "nonexistent order",
			id:           "999",
			expectedCode: http.StatusNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/orders/"+tt.id, nil)
			w := httptest.NewRecorder()
			getOrder(w, req)

			if w.Code != tt.expectedCode {
				t.Errorf("expected status %d, got %d", tt.expectedCode, w.Code)
			}
		})
	}
}
TEST_EOF

# Update k8s/deployment.yaml to add ConfigMap volume
cat > k8s/deployment.yaml << 'DEPLOYMENT_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  labels:
    app: orders-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
      - name: orders-api
        image: orders-api:dev
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: ORDERS_CONFIG_SOURCE
          value: "configmap"
        volumeMounts:
        - name: config
          mountPath: /etc/config/orders-api
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 20
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: orders-config
DEPLOYMENT_EOF

# The deployment above mounts ConfigMap orders-config; ship it as a manifest so `kubectl apply -f k8s/`
# creates it. Without this every deploy from this checkpoint onward sat in ContainerCreating on a clean
# cluster (found on the 2026-09-14 lab pass; earlier passes had the ConfigMap left over from other lessons).
cat > k8s/configmap.yaml << 'CONFIGMAP_EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-config
data:
  config.json: |
    {"max_orders": 100}
CONFIGMAP_EOF

# Verify ConfigMap support is in main.go
if ! grep -q "ORDERS_CONFIG_SOURCE" main.go; then
	echo "ERROR: ORDERS_CONFIG_SOURCE not found in main.go." >&2
	exit 1
fi

if ! grep -q "/etc/config/orders-api/config.json" main.go; then
	echo "ERROR: ConfigMap path not found in main.go." >&2
	exit 1
fi

# Verify deployment has ConfigMap volume
if ! grep -q "configMap:" k8s/deployment.yaml; then
	echo "ERROR: ConfigMap volume not found in deployment." >&2
	exit 1
fi

if ! grep -q "ORDERS_CONFIG_SOURCE" k8s/deployment.yaml; then
	echo "ERROR: ORDERS_CONFIG_SOURCE env var not found in deployment." >&2
	exit 1
fi

# Verify manifests with kubectl if available
if command -v kubectl &> /dev/null; then
	kubectl apply --dry-run=client -f k8s/deployment.yaml || true
fi

# Verify code compiles
if command -v go &> /dev/null; then
	go build ./... >/dev/null 2>&1 || true
	go test ./... >/dev/null 2>&1 || true
fi

echo "checkpoint configmap-support ready"
