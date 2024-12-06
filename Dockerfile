FROM golang:1.23-alpine AS builder

RUN apk update && apk add --no-cache git

#build tailscale
WORKDIR /tailscale
RUN git clone https://github.com/tailscale/tailscale.git . && git checkout v1.78.1

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

RUN GOARCH=$TARGETARCH go install -ldflags="\
      -X tailscale.com/version.longStamp=$VERSION_LONG \
      -X tailscale.com/version.shortStamp=$VERSION_SHORT \
      -X tailscale.com/version.gitCommitStamp=$VERSION_GIT_HASH" \
      -v ./cmd/tailscale ./cmd/tailscaled ./cmd/containerboot

FROM alpine:latest

RUN apk add --no-cache sed tzdata grep dcron openrc bash curl bc keepalived tcptraceroute radvd nano wget ca-certificates iptables ip6tables openssh jq iproute2 net-tools bind-tools htop vim

COPY --from=builder /go/bin/* /usr/local/bin/
# For compat with the previous run.sh, although ideally you should be
# using build_docker.sh which sets an entrypoint for the image.
RUN mkdir /tailscale && ln -s /usr/local/bin/containerboot /tailscale/run.sh

ENV TZ=UTC
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENTRYPOINT ["/tailscale/run.sh"]
