FROM golang:1.24 AS builder
WORKDIR /app
COPY app/ .
RUN CGO_ENABLED=0 go build -o main main.go
EXPOSE 4444
CMD ["./main"]

FROM scratch
COPY --from=builder /app/main /main
EXPOSE 4444
CMD ["/main"]