# Build (hermetic: vendored deps, no network needed)
FROM golang:1.24-alpine AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -mod=vendor -o /pdf-agent .

# Runtime: Chromium is required — three document types (receipt, 1099-NEC,
# bank statement) render HTML via headless Chrome (go-rod). Invoice and W-2
# use pure-Go fpdf and would not need it, but the service ships all five.
FROM alpine:3.24
RUN apk add --no-cache chromium ca-certificates ttf-freefont
ENV ROD_BROWSER_BIN=/usr/bin/chromium-browser
WORKDIR /app
COPY --from=builder /pdf-agent /app/pdf-agent
COPY --from=builder /src/templates /app/templates
EXPOSE 8000
CMD ["/app/pdf-agent"]
