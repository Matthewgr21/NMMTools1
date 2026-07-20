# Remote Target Integration Plan and Handoff

## Current branch

- Repository: `Matthewgr21/NMMTools1`
- Branch: `codex/remote-target-framework`
- Base: `claude/version-8-web-intranet-ayONU`

## Completed milestone

The branch contains a standalone, localhost-only, read-only prototype:

- `targeting.py`: strict hostname validation, DNS forward/reverse checks, WinRM readiness, logged-on-user and SID detection, and safe PowerShell encoding helpers.
- `target_discovery_app.py`: local Flask service bound to `127.0.0.1:5001`.
- `templates/target_discovery.html`: device-name entry and readiness display.
- `Start-TargetDiscovery.ps1`: Windows startup script using `Write-Output`.
- `tests/`: mocked unit and Flask-route coverage.
- `REMOTE_TARGETING.md`: operator and security documentation.

The prototype cannot execute NMMTools tools, perform repairs, register DNS, or accept requests from other computers.

## Why portal integration is intentionally deferred

The existing Version 8 portal contains HTTP and WebSocket paths capable of invoking all registered commands. Its catalog includes high-impact operations such as:

- remote reboot;
- WinRM configuration;
- BitLocker encryption and decryption;
- credential cleanup;
- domain-trust repair;
- Windows Update and network-stack reset;
- browser restore and other profile modifications.

The current development authentication accepts permissive credentials unless production LDAP is configured. Adding target discovery directly to that application without first securing every execution route would make the target field appear safer while leaving an authorization gap.

## Required security gate before integration

The following work should precede any remote repair rollout.

### Authentication

1. Replace development authentication with Windows Integrated Authentication, LDAP over TLS, or the organization's approved SSO.
2. Refuse application startup in production when the default secret key or permissive authentication is active.
3. Set secure session-cookie flags and CSRF protection.
4. Apply the same authentication checks to HTTP and Socket.IO connections.

### Authorization

1. Give every tool an explicit permission and execution-context declaration.
2. Default new tools to denied.
3. Separate read-only discovery, machine repair, user repair, and destructive operations.
4. Require step-up confirmation for reboot, BitLocker, domain, credential, and reset operations.
5. Recheck permissions server-side immediately before execution.

Suggested metadata:

```python
{
    "id": "globalprotect_health",
    "execution_context": "machine",
    "operation_type": "diagnostic",
    "remote_allowed": True,
    "required_role": "helpdesk"
}
```

### Execution safety

1. Replace raw target interpolation in `PowerShellExecutor` with `normalize_target`, `build_execution_script`, and `encode_powershell`.
2. Do not accept arbitrary scripts or command parameters from the browser.
3. Use computer names or FQDNs for Kerberos. Do not set `TrustedHosts` to `*`.
4. Apply timeouts, process termination, concurrency limits, and output-size limits.
5. Use a constrained endpoint or signed allow-listed runner for user-context actions.
6. Record operator, target, tool, parameters, execution context, timestamps, and outcome.

### Testing gate

Tests should prove:

- invalid targets cannot reach PowerShell;
- unauthenticated HTTP and WebSocket requests are rejected;
- non-admin roles cannot run restricted tools;
- DNS or WinRM failures prevent remote execution;
- read-only tools cannot invoke repair commands;
- destructive tools require explicit confirmation;
- user-context operations cannot silently fall back to the service account;
- audit events are written for success, failure, denial, and cancellation.

## Recommended implementation sequence

1. Merge or rebase the current discovery component into a security-hardening branch.
2. Fix production authentication and WebSocket authorization.
3. Add per-tool metadata and deny-by-default authorization.
4. Replace the existing target interpolation with the encoded execution builder.
5. Integrate the read-only target status card into `tool.html`.
6. Allow remote execution only for a new read-only `globalprotect_health` diagnostic.
7. Add GlobalProtect log collection.
8. Add GlobalProtect repairs as individually confirmed actions.
9. Repeat the registered-tool pattern for Nitro and RingCentral.
10. Review high-impact legacy tools separately rather than enabling the full catalog remotely.

## Business Application execution contexts

### GlobalProtect

Machine context:

- PanGPS service;
- installed version;
- virtual adapter;
- routes and DNS;
- system event logs.

User context:

- portal preferences;
- PanGPA state;
- user log paths;
- per-user cache.

### Nitro PDF

Machine context:

- installed version and architecture;
- MSI product and repair state;
- PDF printer;
- Office add-in registration.

User context:

- default PDF association;
- per-user preferences;
- cache and recent crash data.

### RingCentral

Machine context:

- installed components;
- WebView2;
- audio devices;
- firewall and endpoint connectivity.

User context:

- cache and logs;
- selected audio devices;
- per-user startup registration.

User-context repair should be blocked when no interactive user is detected. Detection alone does not authorize impersonation.

## Verification commands

From the `web` directory:

```powershell
python -m unittest discover -s tests -v
python -m py_compile targeting.py target_discovery_app.py
.\Start-TargetDiscovery.ps1
```

Then browse to `http://127.0.0.1:5001` and test a known online workstation, an offline workstation, and an invalid name.
