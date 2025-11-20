FROM alpine:latest

# Build-time arguments
ARG NAMESPACE
ARG REGISTRY

# Set environment variables from build arguments
ENV NAMESPACE=${NAMESPACE:-k8s.io}
ENV REGISTRY=${REGISTRY:-registry.k8s.io}

# Switch to the sweeper user
USER sweeper

WORKDIR /home/sweeper

# Install dependencies, create user, copy script, and set permissions in a single layer
RUN set -ex && \
    # Switch to root to install packages
    USER root && \
    # Add procps for `ps` command and create user
    apk add --no-cache procps && \
    adduser -D -h /home/sweeper sweeper && \
    # Switch back to sweeper user for the rest of the build
    USER sweeper && \
    # Copy script with correct ownership
    COPY --chown=sweeper:sweeper sweeper.sh . && \
    # Make script executable
    chmod +x sweeper.sh

# Set the entrypoint and default command
ENTRYPOINT ["./sweeper.sh"]
CMD []