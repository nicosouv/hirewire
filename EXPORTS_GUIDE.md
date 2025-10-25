# HireWire Exports Guide

## Overview

The export system allows users to generate comprehensive reports of their job search activity and receive them via email. The system is designed to be asynchronous, scalable, and user-friendly.

## Architecture

```
User Request (Frontend)
    ↓
FastAPI Backend (/api/v1/exports)
    ↓
Airflow DAG (generate_export_report)
    ↓
├─ Extract data from DuckDB
├─ Generate Excel/CSV file
├─ Send email with attachment
└─ Update status in database
    ↓
User receives email
```

## Features

- **Flexible date range**: Export data for any period (e.g., last 3 months)
- **Multiple formats**: Excel (recommended) or CSV
- **Comprehensive data**:
  - Summary statistics (total applications, offers, interviews, etc.)
  - Detailed applications list
  - Interview timeline
  - Company statistics
- **Asynchronous processing**: User doesn't wait, receives email when ready
- **Status tracking**: View export history and status in real-time
- **Email delivery**: File sent directly to inbox

## Setup

### 1. Configure SMTP Settings

Add the following variables to your `.env` file:

```bash
# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM=noreply@hirewire.com

# Backend API URL (for Airflow to update status)
BACKEND_API_URL=http://backend:8000
```

### 2. Gmail Setup (Recommended)

If using Gmail:

1. **Enable 2-Factor Authentication**:
   - Go to your Google Account settings
   - Security → 2-Step Verification → Enable

2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Name it "HireWire"
   - Copy the 16-character password

3. **Update `.env`**:
   ```bash
   SMTP_USER=your-email@gmail.com
   SMTP_PASSWORD=xxxx xxxx xxxx xxxx  # The app password from step 2
   ```

### 3. Alternative SMTP Providers

The system works with any SMTP provider:

- **Outlook/Office365**: `smtp.office365.com:587`
- **Yahoo**: `smtp.mail.yahoo.com:587`
- **SendGrid**: `smtp.sendgrid.net:587`
- **Mailgun**: `smtp.mailgun.org:587`

### 4. Restart Services

```bash
docker-compose restart airflow-worker airflow-scheduler backend
```

## Usage

### Via Web Interface (Recommended)

1. Navigate to the Overview page
2. Click "Export Report" button
3. Fill in the export form:
   - **Start Date**: Beginning of period
   - **End Date**: End of period
   - **Format**: Excel or CSV
   - **Email**: Where to send the report
4. Click "Request Export"
5. You'll receive a confirmation
6. Wait for the email (usually 1-3 minutes)

### Via API

```bash
curl -X POST "http://localhost:8000/api/v1/exports/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "start_date": "2024-10-01",
    "end_date": "2025-01-12",
    "format": "excel",
    "recipient_email": "your-email@example.com"
  }'
```

Response:
```json
{
  "id": 1,
  "user_id": 1,
  "start_date": "2024-10-01",
  "end_date": "2025-01-12",
  "format": "excel",
  "recipient_email": "your-email@example.com",
  "status": "processing",
  "created_at": "2025-01-12T20:00:00",
  "updated_at": "2025-01-12T20:00:00"
}
```

### Check Export Status

```bash
curl -X GET "http://localhost:8000/api/v1/exports/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### List All Exports

```bash
curl -X GET "http://localhost:8000/api/v1/exports/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Export File Contents

### Excel Format (Recommended)

The Excel file contains 4 sheets:

1. **Summary**: High-level statistics
   - Total applications
   - Active applications
   - Offers received/accepted
   - Rejections
   - Total interviews
   - Unique companies
   - Average days to first interview

2. **Applications**: Detailed list of all applications
   - Company name
   - Position title
   - Location & salary range
   - Status
   - Application date
   - Source (LinkedIn, etc.)
   - Interview count
   - First/last interview dates
   - Notes

3. **Interviews**: Complete interview timeline
   - Company & position
   - Interview round & type
   - Scheduled date
   - Interviewer name
   - Status
   - Notes

4. **Companies**: Statistics by company
   - Company name & industry
   - Application count
   - Interview count
   - Latest status

### CSV Format

Single file with sections separated by headers:
- `# SUMMARY`
- `# APPLICATIONS`
- `# INTERVIEWS`
- `# COMPANY STATISTICS`

## Troubleshooting

### Export stuck in "processing"

1. Check Airflow UI: http://localhost:8081
2. Find the `generate_export_report` DAG
3. Check the latest run for errors
4. Common issues:
   - SMTP credentials not configured
   - DuckDB file not accessible
   - Email sending failed

### Email not received

1. Check spam/junk folder
2. Verify SMTP credentials in `.env`
3. Check Airflow logs:
   ```bash
   docker-compose logs airflow-worker | grep -A 20 "send_email"
   ```
4. Test SMTP connection:
   ```bash
   docker-compose exec airflow-worker python -c "
   import smtplib
   server = smtplib.SMTP('smtp.gmail.com', 587)
   server.starttls()
   server.login('user@gmail.com', 'password')
   print('SMTP OK')
   "
   ```

### Export status showing "failed"

1. Check the `error_message` field:
   ```bash
   curl -X GET "http://localhost:8000/api/v1/exports/1" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"
   ```
2. Check Airflow task logs for detailed error
3. Common causes:
   - Invalid date range
   - Database connection issues
   - File system permissions

## Database Schema

The `hirewire.exports` table tracks all export requests:

```sql
CREATE TABLE hirewire.exports (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES hirewire.users(id),
    start_date DATE,
    end_date DATE,
    format VARCHAR(10),  -- 'excel' or 'csv'
    recipient_email VARCHAR(255),
    status VARCHAR(20),  -- 'pending', 'processing', 'completed', 'failed'
    airflow_dag_run_id VARCHAR(255),
    file_path TEXT,
    error_message TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    completed_at TIMESTAMP
);
```

## Monitoring

### Via Airflow UI

1. Go to http://localhost:8081
2. Click on `generate_export_report` DAG
3. View recent runs and their status
4. Click on a run to see task details and logs

### Via Database

```sql
-- Recent exports
SELECT id, user_id, status, created_at, completed_at
FROM hirewire.exports
ORDER BY created_at DESC
LIMIT 10;

-- Failed exports
SELECT id, error_message, created_at
FROM hirewire.exports
WHERE status = 'failed'
ORDER BY created_at DESC;

-- Export statistics
SELECT
    status,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 60) as avg_minutes
FROM hirewire.exports
GROUP BY status;
```

## Performance

- **Average export time**: 30-90 seconds
- **Maximum file size**: ~10 MB for 1000 applications
- **Concurrent exports**: Up to 5 simultaneous exports supported
- **Retention**: Export files are kept in `/tmp/exports` (cleared on restart)

## Security

- ✅ JWT authentication required for export requests
- ✅ Users can only access their own exports
- ✅ SMTP credentials stored in environment variables (never in code)
- ✅ Export files are temporary and not stored long-term
- ✅ Email addresses validated before sending

## Future Improvements

- [ ] Export file download from web interface (alternative to email)
- [ ] Scheduled recurring exports (weekly/monthly reports)
- [ ] Custom export templates
- [ ] Export to Google Sheets/Excel Online
- [ ] Export charts and visualizations
- [ ] PDF format support
