# Option A Web Deployment (Agent + Web UI) - Version 8.0

This document defines a **dedicated sub-variant** of the toolset for a web-based deployment using:

- **Web UI** for user access and orchestration
- **Backend API** for job dispatch, auth, auditing, and status
- **Endpoint Agent** (Windows service) that runs tools with elevated privileges

The intent is to **separate UI from execution** and remove interactive console prompts so the toolset can be driven programmatically.

---

## Scope

This sub-variant targets **Option A** only:

- Local endpoint actions remain on endpoints (not in the browser).
- The agent performs privileged operations.
- The web stack handles orchestration, logging, and results.

Any tool that **requires local system access or elevation** belongs in the agent scope.

---

## Component Responsibilities

### 1) Web UI
- Lists tools and provides parameter forms.
- Shows execution status and results.
- Enforces user roles and permissions.

### 2) Backend API
- Auth (SSO/OIDC/AD FS/etc.)
- Job queue and audit log
- Versioning and update orchestration
- Results storage (structured output + logs)

### 3) Endpoint Agent (Windows Service)
- Runs PowerShell modules or scripts **non-interactively**
- Validates signed packages and tool input
- Returns structured output for the UI

---

## Refactor Plan (Option A Only)

### Step 1: Separate UI/Prompts from Logic
- Remove `Read-Host` prompts and replace with parameters.
- Convert tool flows into functions that accept `-Parameter` input.

### Step 2: Create a Tool Module
- Move each tool into a PowerShell module with a stable entry point.
- Standardize input/output so web orchestration can interpret results.

### Step 3: Add an Agent Runner
- A Windows service (or scheduled task runner) that can:
  - Receive tool execution requests
  - Execute as admin
  - Return results and logs

### Step 4: Replace File Share Operations
- Replace network-share updates with API-driven versions.
- Replace file-share logging with API log ingestion.

---

## Minimal “Option A” Starter Layout (Proposed)

```
/
  agent/
    NMM.Agent.Service/
    NMM.Tools.Module/
  api/
    NMM.Tools.Api/
  ui/
    NMM.Tools.Web/
  shared/
    schemas/
```

---

## Notes

- This **does not change** the original script yet; it defines the Option A sub-variant direction.
- Once the direction is approved, the next step is a **module extraction** from the PowerShell script.
