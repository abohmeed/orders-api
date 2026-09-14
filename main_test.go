package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

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
