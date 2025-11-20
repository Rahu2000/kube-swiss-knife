FROM alpine:latest

# Build-time arguments
ARG NAMESPACE
ARG REGISTRY

# Set environment variables from build arguments
ENV NAMESPACE=${NAMESPACE:-k8s.io}
ENV REGISTRY=${REGISTRY:-registry.k8s.io}

WORKDIR /home/sweeper

# Install dependencies and create user as root
RUN set -ex && \
    apk add --no-cache procps && \
    adduser -D -h /home/sweeper sweeper

# Copy script and set permissions
COPY --chown=sweeper:sweeper --chmod=755 sweeper.sh .

# Switch to the non-root user
USER sweeper

# Set the entrypoint and default command
ENTRYPOINT ["./sweeper.sh"]
CMD []