# System Monitoring Scripts

## Over-view
This guide covers the setup and configuration of filesystem, CPU, and memory monitoring scripts with email alerts.

### Available Scripts:
1. **fs_monitor.py** - Python filesystem monitor
2. **fs_monitor.sh** - Bash filesystem monitor
3. **cpu_memory_monitor.py** - Python CPU/Memory monitor
4. **cpu_memory_monitor.sh** - Bash CPU/Memory monitor

---


### For Python Scripts:
```bash
# Install required dependencies
pip install psutil

# For Gmail SMTP (recommended):
# 1. Enable 2-Factor Authentication on Gmail
# 2. Generate App Password: https://myaccount.google.com/apppasswords
```

### For Shell Scripts:
```bash
# Install mail utilities (Ubuntu/Debian)
sudo apt-get install mailutils

# OR install msmtp (alternative)
sudo apt-get install msmtp

# For CentOS/RHEL
sudo yum install mailx
```

---

## Configuration

### Step 1: Configure Email Settings

#### For Python Scripts:
Edit the scripts and update these variables:

```python
SENDER_EMAIL = "your-email@gmail.com"  # Your Gmail address
SENDER_PASSWORD = "your-app-password"  # App password from Google (16 characters)
RECIPIENT_EMAIL = "admin@example.com"  # Alert recipient
```

**Getting Gmail App Password:**
1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Windows Computer"
3. Copy the 16-character password
4. Paste it as SENDER_PASSWORD

#### For Shell Scripts:
Edit the scripts and update:

```bash
SENDER_EMAIL="your-email@example.com"
RECIPIENT_EMAIL="admin@example.com"
```

**For shell scripts, use system mail utilities:**

**Option A: Using mail command (simple)**
```bash
sudo apt-get install mailutils
```

**Option B: Using msmtp (recommended for Gmail)**

Create/edit ~/.msmtprc:
```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           your-email@gmail.com
user           your-email@gmail.com
password       your-app-password

account default : gmail
```

Set permissions:
```bash
chmod 600 ~/.msmtprc
```

### Step 2: Make Scripts Executable

```bash
chmod +x fs_monitor.py
chmod +x cpu_memory_monitor.py
chmod +x fs_monitor.sh
chmod +x cpu_memory_monitor.sh
```

### Step 3: Copy Scripts to System Location (Optional)

```bash
# Copy to standard location
sudo cp fs_monitor.py /usr/local/bin/
sudo cp cpu_memory_monitor.py /usr/local/bin/
sudo cp fs_monitor.sh /usr/local/bin/
sudo cp cpu_memory_monitor.sh /usr/local/bin/
```

---

## Scheduling with Crontab

### Edit Crontab
```bash
crontab -e
```

### Crontab Scheduling Examples

#### Filesystem Monitoring
Monitor every hour:
```cron
0 * * * * /path/to/fs_monitor.py
```

Or using shell script:
```cron
0 * * * * /path/to/fs_monitor.sh
```

#### CPU/Memory Monitoring
Monitor every 5 minutes:
```cron
*/5 * * * * /path/to/cpu_memory_monitor.py
```

Or every 10 minutes:
```cron
*/10 * * * * /path/to/cpu_memory_monitor.sh
```

#### Complete Crontab Example
```cron
# Filesystem check every hour
0 * * * * /usr/local/bin/fs_monitor.py >> /var/log/fs_monitor.log 2>&1

# CPU/Memory check every 5 minutes
*/5 * * * * /usr/local/bin/cpu_memory_monitor.py >> /var/log/cpu_memory_monitor.log 2>&1

# Alternative: Using shell scripts
# 0 * * * * /usr/local/bin/fs_monitor.sh >> /var/log/fs_monitor.log 2>&1
# */5 * * * * /usr/local/bin/cpu_memory_monitor.sh >> /var/log/cpu_memory_monitor.log 2>&1
```

#### Crontab Timing Reference
```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
│ │ │ │ │
* * * * * <command>

Common patterns:
0 * * * *     = Every hour at minute 0
*/5 * * * *   = Every 5 minutes
0 8 * * *     = Daily at 8 AM
0 2 * * 0     = Weekly on Sunday at 2 AM
0 0 1 * *     = Monthly on the 1st at midnight
```

---

## Testing the Scripts

### Test Python Scripts
```bash
# Test filesystem monitor
python3 fs_monitor.py

# Test CPU/Memory monitor
python3 cpu_memory_monitor.py
```

### Test Shell Scripts
```bash
# Test filesystem monitor
./fs_monitor.sh

# Test CPU/Memory monitor
./cpu_memory_monitor.sh
```

### Verify Cron Execution
```bash
# Check cron logs (Ubuntu/Debian)
grep CRON /var/log/syslog

# Check cron logs (CentOS/RHEL)
tail -f /var/log/cron

# View mail in system mailbox
mail

# Check script logs (if configured)
tail -f /var/log/fs_monitor.log
tail -f /var/log/cpu_memory_monitor.log
```

---

## Troubleshooting

### Email Not Sending

**Problem:** Emails are not being sent

**Solutions:**
1. Verify SMTP credentials are correct
2. Check if mail utility is installed: `which mail`
3. For Python: Test with `python3 -m smtplib`
4. Check mail logs: `tail -f /var/log/mail.log`
5. Verify firewall isn't blocking SMTP port 587

### Cron Not Running

**Problem:** Cron job is not executing

**Solutions:**
1. Verify cron daemon is running:
   ```bash
   sudo service cron status
   ```
2. Check crontab syntax: `crontab -l`
3. Ensure full paths are used in crontab
4. Add execute permissions: `chmod +x script.py`
5. Check if Python/bash path is correct in shebang line

### Script Permission Errors

**Problem:** Permission denied when running script

**Solutions:**
```bash
# Make script executable
chmod +x script.py
chmod +x script.sh

# Run with explicit interpreter (Python)
python3 /path/to/script.py

# Run with explicit interpreter (Bash)
bash /path/to/script.sh
```

### High Resource Usage False Alarms

**Solution:** Adjust thresholds in the scripts
```python
CPU_THRESHOLD = 85      # Increase threshold
MEMORY_THRESHOLD = 85   # Increase threshold
```

### Threshold Not Triggering Alerts

**Problem:** Alerts not triggering even when resource usage is high

**Solutions:**
1. Test script manually to see actual usage values
2. Verify threshold values in script
3. Check email configuration
4. Review script logs for errors

---

## Adjusting Thresholds

### Python Scripts
```python
# In fs_monitor.py
THRESHOLD = 80  # Percentage

# In cpu_memory_monitor.py
CPU_THRESHOLD = 90      # Percentage
MEMORY_THRESHOLD = 90   # Percentage
```

### Shell Scripts
```bash
# In fs_monitor.sh
THRESHOLD=80

# In cpu_memory_monitor.sh
CPU_THRESHOLD=90
MEMORY_THRESHOLD=90
```

---

## Log Files

### Default Log Locations
- Filesystem Monitor: `/var/log/fs_monitor.log`
- CPU/Memory Monitor: `/var/log/cpu_memory_monitor.log`
- Cron Logs: `/var/log/syslog` (Ubuntu) or `/var/log/cron` (CentOS)
- Mail Logs: `/var/log/mail.log`

### View Logs
```bash
# Real-time monitoring
tail -f /var/log/fs_monitor.log

# Last 20 lines
tail -20 /var/log/fs_monitor.log

# Search for errors
grep ERROR /var/log/fs_monitor.log
```

---

## Production Recommendations

1. **Multiple Recipients:** Modify email sending to support multiple recipients
2. **Alert Escalation:** Add repeat alert logic for sustained high usage
3. **Database Logging:** Log alerts to database for trending analysis
4. **Slack/Teams Integration:** Replace email with Slack webhooks for faster notifications
5. **Remote Monitoring:** Centralize monitoring on a separate server
6. **Backup Scripts:** Store scripts in version control (Git)
7. **Monitoring Monitoring:** Set up checks to ensure monitor scripts are running

---

## Advanced Configuration

### Slack Integration Example
Replace email sending with Slack webhook:

```python
import requests

def send_slack_alert(title, message):
    webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    payload = {
        "text": f"*{title}*",
        "attachments": [{
            "text": message,
            "color": "danger"
        }]
    }
    requests.post(webhook_url, json=payload)
```

### PagerDuty Integration
For critical alerts, integrate with PagerDuty:

```python
from pdpyras import EventsAPIClientV2

def send_pagerduty_alert(title, message):
    event = {
        "routing_key": "YOUR_ROUTING_KEY",
        "event_action": "trigger",
        "payload": {
            "summary": title,
            "details": message,
            "severity": "critical",
            "source": "Monitoring System"
        }
    }
    # Send to PagerDuty API
```

---

## Maintenance

### Regular Tasks
- Review thresholds quarterly
- Monitor false alert rates
- Update credentials annually
- Archive old logs
- Test recovery procedures

### Backup
```bash
# Backup monitoring scripts
tar -czf monitoring_backup_$(date +%Y%m%d).tar.gz /usr/local/bin/*monitor*

# Backup logs
tar -czf monitoring_logs_$(date +%Y%m%d).tar.gz /var/log/*monitor*
```

---

## Support

For issues or improvements:
1. Review script logs
2. Test scripts manually
3. Check email/SMTP configuration
4. Verify crontab entries
5. Test with simple test emails first

---

**Last Updated:** 2024
**Version:** 1.0
