FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/auth-service .

FROM alpine:3.20
RUN adduser -D -H -u 10001 appuser
WORKDIR /app
COPY --from=builder /out/auth-service /usr/local/bin/auth-service

USER appuser
EXPOSE 8001
ENTRYPOINT ["/usr/local/bin/auth-service"]
