# Orders API Operations Runbook

## Local Development

### Prerequisites
- Go 1.23 or later
- Docker
- Kubernetes (kind)
- kubectl

### Build and Test

Build the service:
```
make build
```

Run unit tests:
```
make test
```

Run the service locally:
```
ORDERS_PORT=8000 ./bin/orders-api
```

The service will start on http://localhost:8000

### Test Endpoints

List orders (should be empty initially):
```
curl http://localhost:8000/orders
```

Create an order:
```
curl -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"sku": "ABC123", "qty": 5}'
```

Get a specific order:
```
curl http://localhost:8000/orders/1
```

## Deploying to Kind Cluster

### Setup

Create the kind cluster (run once):
```
kind create cluster --name gad
```

### Build and Load Image

Build the Docker image:
```
make docker-build
```

Load it into the kind cluster:
```
kind load docker-image orders-api:dev --name gad
```

### Deploy to Kubernetes

Apply the Kubernetes manifests:
```
kubectl apply -f k8s/
```

Verify the deployment:
```
kubectl get deployments -w
```

Wait until both replicas are ready.

### Port Forward for Testing

Forward local port 8080 to the service:
```
kubectl port-forward svc/orders-api 8080:80
```

Test the service through the port forward:
```
curl http://localhost:8080/orders
```

## Troubleshooting

### Check Pod Status

View pod status:
```
kubectl get pods
```

View logs from a specific pod:
```
kubectl logs <pod-name>
```

Stream logs from all pods:
```
kubectl logs -f -l app=orders-api
```

### Check Service Connectivity

Test DNS resolution inside a pod:
```
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup orders-api
```

### Rollback

To rollback to a previous version:
```
kubectl rollout undo deployment/orders-api
```

View rollout history:
```
kubectl rollout history deployment/orders-api
```

## Environment Variables

- `ORDERS_PORT` - The port the service listens on (default: 8000)
- `ORDERS_STORE_LIMIT` - Maximum number of orders to store in memory (default: 1000)

Note: These can be set as environment variables in the Kubernetes Pod spec using env or ConfigMap (added in later lessons).
