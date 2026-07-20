# Remote Target Framework

This milestone adds reusable, read-only target discovery plus execution-building helpers. The working prototype is standalone and does not execute NMMTools repair commands.

## Operator workflow

1. Enter a Windows computer name or FQDN.
2. Select **Check connection**.
3. Review DNS, reachability, WinRM, and logged-on-user results.
4. Use the result to confirm whether the device is ready for a future registered diagnostic. No tool is launched by this prototype.

Remote IP addresses are intentionally rejected. Domain computer names allow PowerShell remoting to use Kerberos without adding arbitrary addresses to WinRM TrustedHosts.

## Discovery results

The `POST /api/target-status` endpoint returns:

- normalized target name;
- resolved network addresses;
- reverse DNS name and forward/reverse agreement;
- ICMP result, when permitted;
- TCP 5985 and WinRM status;
- interactive user and SID, when detectable;
- the execution context available to the current milestone;
- warnings and errors suitable for display and audit logs.

ICMP failure alone does not mark a computer unavailable. WinRM is tested separately because endpoint firewalls commonly block ping while still permitting managed access.

## Execution security

- Target values are validated as DNS computer names or FQDNs.
- Arbitrary URLs, IP addresses, spaces, shell metacharacters, and PowerShell expressions are rejected.
- Trusted tool commands are UTF-16LE/Base64 encoded before being placed inside a remote script block.
- The outer PowerShell invocation uses `-EncodedCommand`.
- NMMTools does not modify `TrustedHosts`.
- The server repeats validation before every execution. UI validation is not treated as a security boundary.

## Current execution contexts

This milestone detects the interactive user but does not impersonate that user and does not integrate with the existing portal execution routes. The result reports whether a future diagnostic could use local or remote-administrator context.

A later Business Applications milestone can use the returned user SID with a signed endpoint runner for explicitly registered user-profile operations. It should never expose arbitrary remote PowerShell.

## DNS registration

The framework validates existing DNS registration. It does not automatically change DNS records. A future repair action may run `Register-DnsClient` on an already reachable endpoint, but DNS repair must remain separate from discovery and require confirmation.

## Running tests

From the `web` directory:

```powershell
python -m unittest discover -s tests -v
python -m py_compile targeting.py target_discovery_app.py
.\Start-TargetDiscovery.ps1
```

Open `http://127.0.0.1:5001` on the same workstation. The service rejects requests from other devices.

The core tests use mocked DNS and management probes, so they can run without contacting production endpoints. Flask route tests require the dependencies in `requirements.txt`.
