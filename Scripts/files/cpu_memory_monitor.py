#!/usr/bin/env python3
"""
CPU and Memory Usage Monitor
Monitors system resources and sends email alert when usage exceeds threshold
Usage: python3 cpu_memory_monitor.py
"""

import os
import sys
import psutil
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import socket

# Configuration
CPU_THRESHOLD = 90  # Alert threshold in percentage
MEMORY_THRESHOLD = 90  # Alert threshold in percentage
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "your-email@gmail.com"  # Change this
SENDER_PASSWORD = "your-app-password"  # Use app-specific password for Gmail
RECIPIENT_EMAIL = "admin@example.com"  # Change this
HOSTNAME = socket.gethostname()

def get_cpu_usage():
    """Get CPU usage percentage (average over 1 second)"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_count = psutil.cpu_count()
        cpu_freq = psutil.cpu_freq()
        
        return {
            'percent': cpu_percent,
            'count': cpu_count,
            'frequency': cpu_freq.current if cpu_freq else 0
        }
    except Exception as e:
        print(f"Error getting CPU usage: {e}", file=sys.stderr)
        return None

def get_memory_usage():
    """Get memory usage information"""
    try:
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        return {
            'total': memory.total,
            'used': memory.used,
            'available': memory.available,
            'percent': memory.percent,
            'swap_total': swap.total,
            'swap_used': swap.used,
            'swap_percent': swap.percent
        }
    except Exception as e:
        print(f"Error getting memory usage: {e}", file=sys.stderr)
        return None

def get_top_processes(top_n=5):
    """Get top N processes by CPU and memory usage"""
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                pinfo = proc.as_dict(attrs=['pid', 'name', 'cpu_percent', 'memory_percent'])
                processes.append(pinfo)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        # Sort by CPU and memory
        top_cpu = sorted(processes, key=lambda x: x['cpu_percent'], reverse=True)[:top_n]
        top_memory = sorted(processes, key=lambda x: x['memory_percent'], reverse=True)[:top_n]
        
        return {'cpu': top_cpu, 'memory': top_memory}
    except Exception as e:
        print(f"Error getting process information: {e}", file=sys.stderr)
        return {'cpu': [], 'memory': []}

def bytes_to_gb(bytes_val):
    """Convert bytes to GB"""
    return bytes_val / (1024 ** 3)

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

def check_system_resources():
    """Check CPU and memory usage and send alert if threshold exceeded"""
    
    print(f"\n{'='*80}")
    print(f"System Resources Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Host: {HOSTNAME}")
    print(f"{'='*80}\n")
    
    # Get CPU info
    cpu_info = get_cpu_usage()
    if not cpu_info:
        print("Error: Unable to retrieve CPU information")
        return False
    
    # Get Memory info
    memory_info = get_memory_usage()
    if not memory_info:
        print("Error: Unable to retrieve memory information")
        return False
    
    # Display CPU Usage
    cpu_status = "⚠️  ALERT" if cpu_info['percent'] >= CPU_THRESHOLD else "✓ OK"
    print(f"CPU Usage")
    print(f"{cpu_status} | Overall: {cpu_info['percent']:.2f}%")
    print(f"   | Cores: {cpu_info['count']}")
    print(f"   | Frequency: {cpu_info['frequency']:.2f} MHz\n")
    
    # Display Memory Usage
    memory_status = "⚠️  ALERT" if memory_info['percent'] >= MEMORY_THRESHOLD else "✓ OK"
    print(f"Memory Usage")
    print(f"{memory_status} | Used: {memory_info['percent']:.2f}% "
          f"({bytes_to_gb(memory_info['used']):.2f} GB / {bytes_to_gb(memory_info['total']):.2f} GB)")
    print(f"   | Available: {bytes_to_gb(memory_info['available']):.2f} GB")
    print(f"   | Swap: {memory_info['swap_percent']:.2f}% "
          f"({bytes_to_gb(memory_info['swap_used']):.2f} GB / {bytes_to_gb(memory_info['swap_total']):.2f} GB)\n")
    
    # Check if alert should be triggered
    alert_triggered = False
    alert_reasons = []
    
    if cpu_info['percent'] >= CPU_THRESHOLD:
        alert_triggered = True
        alert_reasons.append(f"CPU usage is {cpu_info['percent']:.2f}% (threshold: {CPU_THRESHOLD}%)")
    
    if memory_info['percent'] >= MEMORY_THRESHOLD:
        alert_triggered = True
        alert_reasons.append(f"Memory usage is {memory_info['percent']:.2f}% (threshold: {MEMORY_THRESHOLD}%)")
    
    if alert_triggered:
        top_procs = get_top_processes(10)
        
        print("⚠️  Alert threshold exceeded! Sending email...\n")
        
        # Build email body
        alert_body = f"""
System Resources Alert - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Hostname: {HOSTNAME}

ALERTS:
{chr(10).join('• ' + reason for reason in alert_reasons)}

CURRENT STATUS:
CPU Usage: {cpu_info['percent']:.2f}%
  - Cores: {cpu_info['count']}
  - Frequency: {cpu_info['frequency']:.2f} MHz

Memory Usage: {memory_info['percent']:.2f}%
  - Used: {bytes_to_gb(memory_info['used']):.2f} GB / {bytes_to_gb(memory_info['total']):.2f} GB
  - Available: {bytes_to_gb(memory_info['available']):.2f} GB
  - Swap: {memory_info['swap_percent']:.2f}% ({bytes_to_gb(memory_info['swap_used']):.2f} GB / {bytes_to_gb(memory_info['swap_total']):.2f} GB)

TOP 10 PROCESSES BY CPU USAGE:
"""
        for i, proc in enumerate(top_procs['cpu'], 1):
            alert_body += f"{i}. {proc['name']:30} (PID: {proc['pid']:6}) - CPU: {proc['cpu_percent']:6.2f}%\n"
        
        alert_body += f"\nTOP 10 PROCESSES BY MEMORY USAGE:\n"
        for i, proc in enumerate(top_procs['memory'], 1):
            alert_body += f"{i}. {proc['name']:30} (PID: {proc['pid']:6}) - Memory: {proc['memory_percent']:6.2f}%\n"
        
        alert_body += f"\n---\nAutomated System Resources Monitor\n"
        
        subject = f"🚨 ALERT: High System Resource Usage on {HOSTNAME}"
        send_email_alert(subject, alert_body)
        return True
    else:
        print("✓ All system resources within acceptable range")
        return False

if __name__ == "__main__":
    # Verify psutil is installed
    try:
        import psutil
    except ImportError:
        print("Error: psutil module not found!")
        print("Install it with: pip install psutil")
        sys.exit(1)
    
    # Verify email credentials are configured
    if SENDER_EMAIL == "your-email@gmail.com":
        print("⚠️  WARNING: Email configuration not set!")
        print("Please update SENDER_EMAIL, SENDER_PASSWORD, and RECIPIENT_EMAIL in the script")
        sys.exit(1)
    
    check_system_resources()
