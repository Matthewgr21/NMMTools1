# Remote Target Framework

This milestone adds reusable, read-only target discovery and safe remote execution to the NMMTools web interface.

## Operator workflow

1. Enter a Windows computer name or FQDN.
2. Select **Check connection**.
3. Review DNS, reachability, WinRM, and logged-on-user results.
4. Run the selected tool only after the target passes the required preflight.

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

This milestone detects the interactive user but does not impersonate that user. Existing tools continue to run:

- locally in the NMMTools server context; or
- remotely in the authenticated administrative WinRM context.

A later Business Applications milestone can use the returned user SID with a signed endpoint runner for explicitly registered user-profile operations. It should never expose arbitrary remote PowerShell.

## DNS registration

The framework validates existing DNS registration. It does not automatically change DNS records. A future repair action may run `Register-DnsClient` on an already reachable endpoint, but DNS repair must remain separate from discovery and require confirmation.

## Running tests

From the `web` directory:

```powershell
python -m unittest discover -s tests -v
```

The tests use mocked DNS and management probes, so they can run without contacting production endpoints.
