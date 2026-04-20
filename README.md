# entra-id-offboarding

PowerShell helpers for **cloud-first** leaver processing in Microsoft Entra ID / Microsoft 365: disable sign-in, revoke sessions, tidy group memberships, handle licence removal (or dry-run), and dump a simple report.

This is **dangerous automation** if you aim it at the wrong UPN. Run in a test tenant first, use `-WhatIf`, and keep a break-glass admin outside the blast radius.

## Prerequisites

- PowerShell 7+ recommended (5.1 usually works if modules load).
- `Microsoft.Graph` modules: at minimum `Microsoft.Graph.Users`, `Microsoft.Graph.Identity.DirectoryManagement`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Reports` (reports optional for sign-in activity — not used in these basic scripts).

## Typical Graph scopes (least privilege mindset)

You will realistically end up with a subset of:

- `User.ReadWrite.All` — disable account, licence changes.
- `Directory.ReadWrite.All` — group membership removals (many tenants treat this as “heavy”; custom roles may be tighter).
- `GroupMember.ReadWrite.All` — if you split permissions.

Start with `Connect-MgGraph -TenantId '00000000-0000-0000-0000-000000000000' -Scopes User.ReadWrite.All,Directory.ReadWrite.All` and trim once you know what your security team allows.

## Hybrid estates

These scripts target **cloud directory objects**. If you sync from on-premises AD, some attributes and group memberships are owned by HR/provisioning elsewhere — see `docs/offboarding-workflow.md` before you “clean” things Graph will just re-hydrate on the next sync.

## How to run

```powershell
# Example: dry orchestration
.\scripts\Invoke-Offboarding.ps1 -UserPrincipalName 'leaver@contoso.onmicrosoft.com' -WhatIf

# Individual steps also exist if you prefer not to use the orchestrator.
```

## Operational risks

- Licence removal can strand mailbox/data retention expectations — check legal hold and retention before you strip SKU.
- Shared mailboxes and delegates are not fully modelled here; manual review still matters.
- Destructive steps support `-WhatIf` / `-Confirm:$false` only where sensible — read each script.
