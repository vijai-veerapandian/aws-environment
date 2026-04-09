#!/bin/bash
#
# CPU and Memory Usage Monitor
# Monitors system resources and sends email alert when usage exceeds threshold
# Usage: ./cpu_memory_monitor.sh
# Add to crontab: */5 * * * * /path/to/cpu_memory_monitor.sh
#

# Configuration
CPU_THRESHOLD=90
MEMORY_THRESHOLD=90
SENDER_EMAIL="your-email@example.com"  # Change this
RECIPIENT_EMAIL="admin@example.com"    # Change this
HOSTNAME=$(hostname)
LOG_FILE="/var/log/cpu_memory_monitor.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to get CPU usage
get_cpu_usage() {
    # Calculate CPU usage using top command (average over 1 second)
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
    local cpu_usage=$(echo "100 - $cpu_idle" | bc 2>/dev/null || echo "0")
    
    # If bc is not available, try alternative method
    if [ "$cpu_usage" = "0" ]; then
        cpu_usage=$(ps aux | awk '{sum+=$3} END {print sum}' | cut -d'.' -f1)
    fi
    
    echo "$cpu_usage"
}

# Function to get memory usage
get_memory_usage() {
    # Get memory usage percentage from free command
    local mem_total=$(free | grep Mem | awk '{print $2}')
    local mem_used=$(free | grep Mem | awk '{print $3}')
    local mem_percent=$(awk "BEGIN {printf \"%.2f\", ($mem_used/$mem_total)*100}")
    
    echo "$mem_percent"
}

# Function to get memory details
get_memory_details() {
    local mem_total=$(free -h | grep Mem | awk '{print $2}')
    local mem_used=$(free -h | grep Mem | awk '{print $3}')
    local mem_available=$(free -h | grep Mem | awk '{print $7}')
    local swap_total=$(free -h | grep Swap | awk '{print $2}')
    local swap_used=$(free -h | grep Swap | awk '{print $3}')
    
    echo "Total: $mem_total | Used: $mem_used | Available: $mem_available | Swap: $swap_used/$swap_total"
}

# Function to get top processes by CPU
get_top_cpu_processes() {
    local top_n=${1:-5}
    echo "Top $top_n processes by CPU usage:"
    ps aux --sort=-%cpu | head -n $((top_n + 1)) | tail -n $top_n | \
    awk '{printf "  %s (PID: %d) - CPU: %.2f%%\n", $11, $2, $3}'
}

# Function to get top processes by memory
get_top_memory_processes() {
    local top_n=${1:-5}
    echo "Top $top_n processes by memory usage:"
    ps aux --sort=-%mem | head -n $((top_n + 1)) | tail -n $top_n | \
    awk '{printf "  %s (PID: %d) - Memory: %.2f%%\n", $11, $2, $4}'
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
        return 1
    fi
}

# Function to send email using msmtp
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
    
    log_message "ERROR: No email utility available"
    return 1
}

# Function to check system resources
check_system_resources() {
    echo ""
    echo "=================================="
    echo "System Resources Report"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $HOSTNAME"
    echo "=================================="
    echo ""
    
    # Get CPU and Memory usage
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local memory_details=$(get_memory_details)
    
    # Display CPU Usage
    if (( $(echo "$cpu_usage >= $CPU_THRESHOLD" | bc -l) )); then
        cpu_status="⚠️  ALERT"
        log_message "ALERT: CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
    else
        cpu_status="✓ OK"
    fi
    
    echo "CPU Usage"
    echo "$cpu_status | Current: ${cpu_usage}%"
    echo "   | Cores: $(nproc)"
    echo ""
    
    # Display Memory Usage
    if (( $(echo "$memory_usage >= $MEMORY_THRESHOLD" | bc -l) )); then
        memory_status="⚠️  ALERT"
        log_message "ALERT: Memory usage is ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)"
    else
        memory_status="✓ OK"
    fi
    
    echo "Memory Usage"
    echo "$memory_status | Used: ${memory_usage}%"
    echo "   | $memory_details"
    echo ""
    echo "=================================="
    echo ""
    
    # Check if alert should be triggered
    local alert_triggered=0
    local alert_reasons=""
    
    if (( $(echo "$cpu_usage >= $CPU_THRESHOLD" | bc -l) )); then
        alert_triggered=1
        alert_reasons="${alert_reasons}• CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)\n"
    fi
    
    if (( $(echo "$memory_usage >= $MEMORY_THRESHOLD" | bc -l) )); then
        alert_triggered=1
        alert_reasons="${alert_reasons}• Memory usage is ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)\n"
    fi
    
    # Send alert if threshold exceeded
    if [ $alert_triggered -eq 1 ]; then
        echo "⚠️  Alert threshold exceeded! Sending email..."
        
        # Get top processes
        local top_cpu=$(get_top_cpu_processes 10)
        local top_memory=$(get_top_memory_processes 10)
        
        subject="🚨 ALERT: High System Resource Usage on $HOSTNAME"
        body="System Resources Alert - $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $HOSTNAME

ALERTS:
$alert_reasons

CURRENT STATUS:
CPU Usage: ${cpu_usage}%
  - Cores: $(nproc)

Memory Usage: ${memory_usage}%
  - $memory_details

$top_cpu

$top_memory

---
Automated System Resources Monitor"
        
        send_email_alert "$subject" "$body"
        return 0
    else
        echo "✓ All system resources within acceptable range"
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
    
    check_system_resources
}

# Run main function
main
