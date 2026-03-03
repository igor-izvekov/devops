FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN go build -o app ./cmd/main.go

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/app .
RUN chmod +x app
EXPOSE 8080
CMD ["./app"]