# NMM System Toolkit - Web Intranet Edition

**Version 8.0 Web** | Enterprise IT Administration Portal

A comprehensive web-based IT administration toolkit designed for company intranet deployment. This edition provides browser-based access to all 60+ diagnostic and repair tools from the NMM System Toolkit.

---

## Features

- **Browser-Based Access**: Access all toolkit features from any device with a web browser
- **Real-Time Output**: Watch tool execution output in real-time via WebSocket
- **Role-Based Access**: Administrator vs standard user tool restrictions
- **Remote Execution**: Execute tools on local or remote computers (PowerShell remoting)
- **Modern UI**: Clean, responsive Bootstrap 5 interface with dark theme
- **Session Management**: Secure authentication with configurable session timeout
- **Audit Logging**: Track all tool executions with user and timestamp

---

## Quick Start

### Prerequisites

- Python 3.10 or higher
- Windows Server 2016+ or Windows 10/11
- PowerShell 5.1+
- Network access to target computers (for remote execution)

### Installation

1. **Clone or copy the web folder** to your intranet server

2. **Run the startup script**:
   ```powershell
   # PowerShell
   .\Start-NMMWebServer.ps1 -Install

   # Or Command Prompt
   start_server.bat
   ```

3. **Access the toolkit** at `http://localhost:5000`

### Manual Installation

```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the server
python app.py
```

---

## Tool Categories

| Category | Tools | Description |
|----------|-------|-------------|
| **System Diagnostics** | 16 | System info, disk space, network, services, events |
| **Cloud & Collaboration** | 10 | Azure AD, M365, OneDrive, Teams, Intune |
| **Advanced Repair** | 8 | DISM, SFC, ChkDsk, Windows Update repair |
| **Laptop & Mobile** | 11 | Battery, Wi-Fi, VPN, BitLocker, docking |
| **Browser Tools** | 3 | Backup, restore, cache management |
| **Common Issues** | 10 | Printer, audio, search, Start Menu fixes |
| **Quick Fixes** | 10 | One-click automated repairs |

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | Flask session encryption key | (auto-generated) |
| `FLASK_ENV` | Environment mode | `development` |
| `LDAP_SERVER` | LDAP server for authentication | (disabled) |
| `PORT` | Server port | `5000` |

### Authentication

By default, the toolkit accepts any username/password for development. For production:

1. **Edit `config.py`** to configure LDAP/AD authentication
2. **Set environment variables** for LDAP server details
3. **Install python-ldap** if using AD authentication:
   ```bash
   pip install python-ldap
   ```

### LDAP/Active Directory Example

```python
# config.py - ProductionConfig class
LDAP_ENABLED = True
LDAP_SERVER = 'ldap://dc.company.local'
LDAP_BASE_DN = 'DC=company,DC=local'
LDAP_USER_DN = 'CN=Users'
```

---

## Production Deployment

### IIS Deployment (Recommended for Windows)

1. **Install URL Rewrite and ARR** modules for IIS

2. **Create an Application Pool**:
   - .NET CLR Version: No Managed Code
   - Identity: Service account with admin rights

3. **Create web.config**:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <configuration>
     <system.webServer>
       <handlers>
         <add name="Python" path="*" verb="*"
              modules="FastCgiModule"
              scriptProcessor="C:\Python311\python.exe|C:\NMMTools\web\wsgi.py"
              resourceType="Unspecified" />
       </handlers>
     </system.webServer>
   </configuration>
   ```

### Gunicorn (Linux/Windows with WSL)

```bash
# Production with SocketIO support
gunicorn -k eventlet -w 1 -b 0.0.0.0:5000 wsgi:application

# Or with SSL
gunicorn -k eventlet -w 1 -b 0.0.0.0:443 \
  --certfile=/path/to/cert.pem \
  --keyfile=/path/to/key.pem \
  wsgi:application
```

### Windows Service

Use **NSSM** (Non-Sucking Service Manager) to run as a Windows service:

```batch
nssm install NMMToolkitWeb "C:\NMMTools\web\venv\Scripts\python.exe" "C:\NMMTools\web\app.py"
nssm set NMMToolkitWeb AppDirectory "C:\NMMTools\web"
nssm start NMMToolkitWeb
```

---

## Remote Execution

The toolkit supports executing tools on remote computers via PowerShell remoting.

### Requirements

1. **Enable PowerShell Remoting** on target computers:
   ```powershell
   Enable-PSRemoting -Force
   ```

2. **Configure TrustedHosts** (if not in domain):
   ```powershell
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"
   ```

3. **Enter remote computer name** in the Target field when running a tool

---

## API Reference

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/health` | Health check |
| `GET` | `/api/categories` | List all tool categories |
| `GET` | `/api/system-info` | Get current system information |
| `POST` | `/api/run-tool` | Execute a tool |
| `GET` | `/api/job-status/<id>` | Get job execution status |

### Run Tool Example

```javascript
fetch('/api/run-tool', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        tool_id: 'sys_info',
        target_host: 'localhost'
    })
})
```

---

## Security Considerations

1. **Network Isolation**: Deploy only on internal network/intranet
2. **HTTPS**: Enable SSL/TLS in production
3. **Authentication**: Configure LDAP/AD authentication
4. **Firewall**: Restrict access to authorized IP ranges
5. **Audit Logging**: Monitor `nmm_toolkit_web.log` for suspicious activity
6. **Principle of Least Privilege**: Configure tool restrictions based on user roles

---

## Troubleshooting

### Common Issues

**"PowerShell execution failed"**
- Ensure PowerShell execution policy allows script execution
- Run `Set-ExecutionPolicy RemoteSigned -Scope LocalMachine`

**"Access Denied" errors**
- Run the web server as Administrator
- Ensure service account has required permissions

**"Cannot connect to remote computer"**
- Verify PowerShell remoting is enabled
- Check firewall rules (ports 5985/5986)
- Verify credentials and TrustedHosts configuration

---

## License

NMM System Toolkit - For internal IT use only.

---

## Version History

- **8.0 Web** - Initial web intranet edition
  - Complete Flask-based web interface
  - Real-time output via WebSocket
  - All 60+ tools accessible via browser
  - Role-based access control
  - Remote execution support
