FROM alpine:latest

# Install tools
RUN apk add --no-cache bash rclone sqlite zip msmtp

# Set timezone (Optional, but good for logs)
RUN apk add --no-cache tzdata

WORKDIR /app

# Copy scripts
COPY backup.sh /app/backup.sh
COPY report.sh /app/report.sh
COPY crontab /app/crontab

# Permissions
RUN chmod +x /app/backup.sh /app/report.sh

# Apply cron
RUN crontab /app/crontab

# Run cron in foreground
CMD ["crond", "-f", "-l", "2"]
