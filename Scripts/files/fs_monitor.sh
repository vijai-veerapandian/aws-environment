#!/bin/bash
#
# Filesystem Capacity Monitor
# Monitors disk usage and sends email alert when capacity exceeds threshold
# Usage: ./fs_monitor.sh
# Add to crontab: 0 * * * * /path/to/fs_monitor.sh
#

# Configuration
THRESHOLD=80
SENDER_EMAIL="your-email@example.com"  # Change this
RECIPIENT_EMAIL="admin@example.com"    # Change this
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT=587
HOSTNAME=$(hostname)
LOG_FILE="/var/log/fs_monitor.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to send email using mail command
send_email_with_mail() {
    local subject="$1"
    local body="$2"
    
    echo "$body" | mail -s "$subject" "$RECIPIENT_EMAIL" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Alert email sent successfully"
        return 0
    else
        echo "✗ Failed to send email using mail command" >&2
        return 1
    fi
}

# Function to send email using msmtp (alternative method)
send_email_with_msmtp() {
    local subject="$1"
    local body="$2"
    
    {
        echo "To: $RECIPIENT_EMAIL"
        echo "Subject: $subject"
        echo "From: $SENDER_EMAIL"
        echo ""
        echo "$body"
    } | msmtp -a default "$RECIPIENT_EMAIL" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Alert email sent successfully"
        return 0
    else
        echo "✗ Failed to send email using msmtp" >&2
        return 1
    fi
}

# Function to send email alert
send_email_alert() {
    local subject="$1"
    local body="$2"
    
    # Try using mail command first
    if command -v mail &> /dev/null; then
        send_email_with_mail "$subject" "$body"
        return $?
    fi
    
    # Fall back to msmtp if available
    if command -v msmtp &> /dev/null; then
        send_email_with_msmtp "$subject" "$body"
        return $?
    fi
    
    echo "✗ No email utility available (mail or msmtp)" >&2
    log_message "ERROR: No email utility available"
    return 1
}

# Function to check filesystem usage
check_filesystem_usage() {
    echo ""
    echo "=================================="
    echo "Filesystem Usage Report"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $HOSTNAME"
    echo "=================================="
    echo ""
    
    local alert_triggered=0
    local alert_details=""
    
    # Get filesystem usage information
    df_output=$(df -h | grep -v "^Filesystem" | grep -v "^tmpfs")
    
    while IFS= read -r line; do
        # Parse df output
        filesystem=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        available=$(echo "$line" | awk '{print $4}')
        percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        mountpoint=$(echo "$line" | awk '{print $6}')
        
        # Check if percent is a valid number
        if ! [[ "$percent" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        # Display status
        if [ "$percent" -ge "$THRESHOLD" ]; then
            status="⚠️  ALERT"
            alert_triggered=1
            alert_details="${alert_details}  • $mountpoint: $percent% used ($used / $size)\n"
            echo "✗ ALERT | $mountpoint | Used: ${percent}% ($used / $size)"
        else
            status="✓ OK"
            echo "✓ OK    | $mountpoint | Used: ${percent}% ($used / $size)"
        fi
    done <<< "$df_output"
    
    echo ""
    echo "=================================="
    echo ""
    
    # Send alert if threshold exceeded
    if [ $alert_triggered -eq 1 ]; then
        log_message "ALERT: Disk usage exceeded threshold of ${THRESHOLD}%"
        
        subject="🚨 ALERT: High Disk Usage on $HOSTNAME"
        body="Disk Usage Alert - $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $HOSTNAME
Threshold: ${THRESHOLD}%

Filesystems exceeding threshold:
$alert_details
Please investigate and take necessary action.

---
Automated Filesystem Monitor"
        
        echo "⚠️  Alert threshold exceeded! Sending email..."
        send_email_alert "$subject" "$body"
        
        return 0
    else
        echo "✓ All filesystems within acceptable range"
        log_message "INFO: All filesystems within acceptable range"
        return 1
    fi
}

# Main execution
main() {
    # Verify email is configured
    if [ "$SENDER_EMAIL" = "your-email@example.com" ]; then
        echo "⚠️  WARNING: Email configuration not set!"
        echo "Please update SENDER_EMAIL and RECIPIENT_EMAIL in the script"
        exit 1
    fi
    
    # Verify mail utility is available
    if ! command -v mail &> /dev/null && ! command -v msmtp &> /dev/null; then
        echo "⚠️  WARNING: No email utility found!"
        echo "Install 'mailutils' (mail command) or 'msmtp' for email functionality"
        echo "Ubuntu/Debian: sudo apt-get install mailutils"
        echo "CentOS/RHEL: sudo yum install mailx"
    fi
    
    check_filesystem_usage
}

# Run main function
main
