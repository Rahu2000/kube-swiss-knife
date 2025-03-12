FROM --platform=$TARGETPLATFORM alpine:latest

# Install necessary packages, create user, copy script, make it executable, and change ownership in a single RUN command
RUN apk add --no-cache bash jq && \
    adduser -D -h /home/sweeper sweeper && \
    mkdir -p /home/sweeper && \
    chown -R sweeper:sweeper /home/sweeper

# Copy the sweeper script into the home directory
COPY sweeper.sh /home/sweeper/sweeper.sh

# Make the script executable and change ownership
RUN chmod +x /home/sweeper/sweeper.sh && \
    chown sweeper:sweeper /home/sweeper/sweeper.sh

# Switch to the sweeper user
USER sweeper

# Set the entrypoint to the sweeper script
ENTRYPOINT ["/bin/bash", "/home/sweeper/sweeper.sh"]