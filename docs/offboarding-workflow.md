# Offboarding workflow

Order of operations for a **cloud-only** leaver where Entra ID is authoritative. If you are hybrid, treat anything re-synced from on-prem as a separate workstream — disabling in cloud without fixing the source account often ends in zombie re-enablement.

## 1. Freeze access fast

- **Disable sign-in** on the user object — stops most interactive login immediately-ish.
- **Revoke refresh tokens / sessions** — catches “already logged in” clients. Not magic for every app, but cheap.

## 2. Mailbox / collaboration reality check (manual)

This repo does not auto-convert mailboxes or re-home OneDrive. Before licence removal:

- Legal hold / litigation hold?
- Shared mailbox needed?
- Delegates and calendar ownership?

If you skip this, you will learn why people have runbooks.

## 3. Group membership

- Remove **cloud-managed** memberships that are only there for access.
- **Do not** blindly remove groups you do not recognise — some are licence groups, some are dynamic, some reappear because of sync.

For hybrid: groups tied to on-prem may come back. Fix AD or use cloud-only groups for what you control.

## 4. Licences

- **Report first** (`Export-OffboardingReport.ps1`) so you know SKU IDs actually assigned.
- Remove licences when retention and mailbox decisions are done.
- Some tenants use group-based licensing — removing the user from the group may be the real lever instead of direct assignment.

## 5. Data and device cleanup (mostly manual)

- Wipe company devices from Intune if that is your standard.
- Transfer OneDrive ownership per org policy.

## 6. Final account state

Some orgs keep disabled accounts for audit; others delete after N days. Deletion is out of scope for these scripts — that deserves its own checklist and backup story.

## Why this order

Speed first (sessions), then decisions that need humans (mailbox), then mechanical cleanup (groups/licences). The failure mode you want to avoid is stripping licences while someone still has a live session on a thick client — rare, but annoying.
