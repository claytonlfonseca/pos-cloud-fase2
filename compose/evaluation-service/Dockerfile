FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY . .
RUN rm -f go.sum && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/evaluation-service .

FROM alpine:3.20
RUN adduser -D -H -u 10001 appuser
WORKDIR /app
COPY --from=builder /out/evaluation-service /usr/local/bin/evaluation-service

USER appuser
EXPOSE 8004
ENTRYPOINT ["/usr/local/bin/evaluation-service"]
