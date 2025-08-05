FROM golang:1.24.4-alpine AS builder

RUN apk update && apk add --no-cache git

#build tailscale
WORKDIR /tailscale
RUN git clone https://github.com/tailscale/tailscale.git . && git checkout v1.86.2

RUN go mod download

# Pre-build some stuff before the following COPY line invalidates the Docker cache.
RUN go install \
    github.com/aws/aws-sdk-go-v2/aws \
    github.com/aws/aws-sdk-go-v2/config \
    gvisor.dev/gvisor/pkg/tcpip/adapters/gonet \
    gvisor.dev/gvisor/pkg/tcpip/stack \
    golang.org/x/crypto/ssh \
    golang.org/x/crypto/acme \
    github.com/coder/websocket \
    github.com/mdlayher/netlink

# see build_docker.sh
ARG VERSION_LONG=""
ENV VERSION_LONG=$VERSION_LONG
ARG VERSION_SHORT=""
ENV VERSION_SHORT=$VERSION_SHORT
ARG VERSION_GIT_HASH=""
ENV VERSION_GIT_HASH=$VERSION_GIT_HASH
ARG TARGETARCH

RUN CGO_ENABLED=0 GOARCH=$TARGETARCH go install -trimpath -ldflags="-s -w -buildid= \
      -X tailscale.com/version.longStamp=$VERSION_LONG \
      -X tailscale.com/version.shortStamp=$VERSION_SHORT \
      -X tailscale.com/version.gitCommitStamp=$VERSION_GIT_HASH" \
      -v ./cmd/tailscale ./cmd/tailscaled ./cmd/containerboot
RUN mkdir /tmp/tailscale && ln -s /usr/local/bin/containerboot /tmp/tailscale/run.sh

FROM scratch

COPY --from=builder /go/bin/* /usr/local/bin/
COPY --from=builder /tmp/tailscale /tailscale
COPY --from=builder /etc/ssl /etc/ssl

ENTRYPOINT ["/tailscale/run.sh"]
