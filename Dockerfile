FROM golang:1.24 AS builder
WORKDIR /app
COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux go build -o main main.go

FROM alpine:3.19
RUN apk add --no-cache wget
COPY --from=builder /app/main /main
EXPOSE 4444
HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1
CMD ["/main"]