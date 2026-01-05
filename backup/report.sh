#!/bin/bash

# Configuration
LOG_FILE="/var/log/backup.log"
REPORT_SUBJECT="Vaultwarden Backup Report - $(date +'%Y-%m-%d')"

# SMTP Configuration check
if [ -z "$SMTP_HOST" ] || [ -z "$TO_EMAIL" ]; then
    echo "SMTP configuration missing. Skipping report."
    exit 0
fi

# Configure msmtp on the fly
cat <<EOF > /etc/msmtprc
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           $SMTP_HOST
port           ${SMTP_PORT:-587}
from           $SMTP_USER
user           $SMTP_USER
password       $SMTP_PASS
EOF

chmod 600 /etc/msmtprc

# Extract log entries from the last 24 hours (roughly)
TODAY=$(date +'%Y-%m-%d')
if [ -f "$LOG_FILE" ]; then
    LOG_CONTENT=$(tail -n 100 "$LOG_FILE")
    # Count successes
    SUCCESS_COUNT=$(echo "$LOG_CONTENT" | grep -c "Success: Uploaded")
    FAIL_COUNT=$(echo "$LOG_CONTENT" | grep -c "Error:")
else
    LOG_CONTENT="No log file found at $LOG_FILE. Backup might not have run yet."
    SUCCESS_COUNT=0
    FAIL_COUNT=0
fi

BODY="Vaultwarden Backup Daily Report
-----------------------------------
Date: $(date)
Total Successful Uploads (Last ~24h): $SUCCESS_COUNT
Total Failed Uploads     (Last ~24h): $FAIL_COUNT

--- Log Snippet (Last 100 lines) ---
$LOG_CONTENT
"

# Send Email
echo -e "Subject: $REPORT_SUBJECT\r\n\r\n$BODY" | msmtp "$TO_EMAIL"

if [ $? -eq 0 ]; then
    echo "[$(date)] Report sent successfully to $TO_EMAIL"
else
    echo "[$(date)] Failed to send report"
fi
