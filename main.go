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
	mux.HandleFunc("GET /orders", listOrders)
	mux.HandleFunc("POST /orders", createOrder)
	mux.HandleFunc("GET /orders/{id}", getOrder)

	addr := ":" + port
	log.Printf(`level=info msg="server starting" addr=%s`, addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf(`level=error msg="server failed" error=%s`, err)
	}
}
