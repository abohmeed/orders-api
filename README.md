# Orders API

A small HTTP service for the Sahl Market Platform team. Orders API manages orders for Sahl Market's online grocery platform.

## What's in this repository

- **main.go** — The HTTP service with GET and POST endpoints for orders
- **Dockerfile** — Container definition for the service
- **k8s/** — Kubernetes manifests (Deployment and Service)
- **terraform/** — Terraform module for provisioning infrastructure (S3 bucket and IAM role)
- **.github/workflows/** — CI/CD pipeline configuration
- **Makefile** — Build and run targets

## Quick Start

### Prerequisites

- Go 1.23 or later
- Docker
- kubectl and kind (for Kubernetes)

### Run locally

```bash
make test
make run
```

The service listens on `http://localhost:8000`.

### Test the API

```bash
# List orders
curl http://localhost:8000/orders

# Create an order
curl -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"sku": "ABC123", "qty": 5}'

# Get an order
curl http://localhost:8000/orders/1
```

### Deploy to Kubernetes

Build and load the image into your kind cluster:

```bash
make docker-build
kind load docker-image orders-api:dev --name gad
kubectl apply -f k8s/
```

## API Endpoints

### GET /orders

List all orders.

**Response:**
```json
[
  {
    "id": "1",
    "sku": "ABC123",
    "qty": 5,
    "created_at": "2024-01-15T10:30:00Z"
  }
]
```

### POST /orders

Create a new order.

**Request:**
```json
{
  "sku": "ABC123",
  "qty": 5
}
```

**Response:** (201 Created)
```json
{
  "id": "1",
  "sku": "ABC123",
  "qty": 5,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Validation:**
- `sku` must not be empty
- `qty` must be a positive integer

### GET /orders/{id}

Get a specific order by ID.

**Response:**
```json
{
  "id": "1",
  "sku": "ABC123",
  "qty": 5,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Errors:**
- 404 if the order doesn't exist

## Configuration

The service accepts these environment variables:

- `ORDERS_PORT` — Port to listen on (default: 8000)
- `ORDERS_STORE_LIMIT` — Maximum number of orders in memory (default: 1000)

## Repository Map

This is the starting state of the orders-api repository. Throughout the course:

- **Section 2** — Learn why models can miss mistakes in code
- **Section 3** — Practice verifying code before applying it
- **Section 4** — Use AI to write Dockerfiles, Kubernetes manifests, and Terraform
- **Section 5** — Use Claude Code to add health checks
- **Section 6** — Troubleshoot Kubernetes failures
- **Section 7** — Generate a complete CI/CD pipeline
- **Sections 8–11** — Use agents to monitor and improve the service

## License

MIT. Copyright 2026 Sahl Market Platform team.
