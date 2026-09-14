FROM golang:1.27-alpine

WORKDIR /app

COPY go.mod go.sum* ./
COPY . .

RUN go build -o /app/orders-api .

EXPOSE 8000

CMD ["/orders-api"]
