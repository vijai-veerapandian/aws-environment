#!/usr/bin/env python3
"""
Filesystem Capacity Monitor
Monitors disk usage and sends email alert when capacity exceeds threshold
Usage: python3 fs_monitor.py
"""

import os
import sys
import shutil
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import socket

# Configuration
THRESHOLD = 80  # Alert threshold in percentage
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "your-email@gmail.com"  # Change this
SENDER_PASSWORD = "your-app-password"  # Use app-specific password for Gmail
RECIPIENT_EMAIL = "admin@example.com"  # Change this
HOSTNAME = socket.gethostname()

def get_disk_usage():
    """Get disk usage for all mounted filesystems"""
    disk_info = {}
    
    try:
        partitions = shutil.disk_usage('/')
        
        # Get all mount points
        result = os.popen('df -h | grep -v "^Filesystem"').read().strip().split('\n')
        
        for line in result:
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 6:
                try:
                    filesystem = parts[0]
                    size = parts[1]
                    used = parts[2]
                    available = parts[3]
                    percent_str = parts[4].rstrip('%')
                    percent = float(percent_str)
                    mount_point = parts[5]
                    
                    disk_info[mount_point] = {
                        'filesystem': filesystem,
                        'size': size,
                        'used': used,
                        'available': available,
                        'percent': percent
                    }
                except (ValueError, IndexError):
                    continue
    except Exception as e:
        print(f"Error getting disk usage: {e}", file=sys.stderr)
    
    return disk_info

def send_email_alert(subject, body):
    """Send email alert"""
    try:
        msg = MIMEMultipart()
        msg['From'] = SENDER_EMAIL
        msg['To'] = RECIPIENT_EMAIL
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'plain'))
        
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)
        server.quit()
        
        print(f"✓ Alert email sent successfully")
        return True
    except Exception as e:
        print(f"✗ Failed to send email: {e}", file=sys.stderr)
        return False

def check_filesystem_usage():
    """Check filesystem usage and send alert if threshold exceeded"""
    disk_info = get_disk_usage()
    
    if not disk_info:
        print("Error: Unable to retrieve disk usage information")
        return False
    
    alert_triggered = False
    alert_details = []
    
    print(f"\n{'='*80}")
    print(f"Filesystem Usage Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Host: {HOSTNAME}")
    print(f"{'='*80}\n")
    
    for mount_point, info in disk_info.items():
        status = "⚠️  ALERT" if info['percent'] >= THRESHOLD else "✓ OK"
        print(f"{status} | {mount_point:20} | Used: {info['percent']:6.2f}% "
              f"({info['used']:>8} / {info['size']:>8})")
        
        if info['percent'] >= THRESHOLD:
            alert_triggered = True
            alert_details.append(
                f"  • {mount_point}: {info['percent']:.2f}% used "
                f"({info['used']} / {info['size']})"
            )
    
    print(f"\n{'='*80}\n")
    
    if alert_triggered:
        subject = f"🚨 ALERT: High Disk Usage on {HOSTNAME}"
        body = f"""
Disk Usage Alert - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Hostname: {HOSTNAME}
Threshold: {THRESHOLD}%

Filesystems exceeding threshold:
{chr(10).join(alert_details)}

Please investigate and take necessary action.

---
Automated Filesystem Monitor
"""
        print("⚠️  Alert threshold exceeded! Sending email...")
        send_email_alert(subject, body)
        return True
    else:
        print("✓ All filesystems within acceptable range")
        return False

if __name__ == "__main__":
    # Verify email credentials are configured
    if SENDER_EMAIL == "your-email@gmail.com":
        print("⚠️  WARNING: Email configuration not set!")
        print("Please update SENDER_EMAIL, SENDER_PASSWORD, and RECIPIENT_EMAIL in the script")
        sys.exit(1)
    
    check_filesystem_usage()
