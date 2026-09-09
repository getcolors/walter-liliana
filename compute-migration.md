# Compute migration prerequisites

Installed getcolors/walter revision `3c385901dea62fc09712ca2ab61deec8623621dc`. The root launcher exactly
matches the installed Package Skill payload from a verified Skills CLI install.
This remains a manual copy with no invented lockfile.
The launcher pins source 726871d and colors-compute 5040d936.

This refresh changes tracked payloads and configuration only. No live cloud
calls, state reads/transfers, private credential/key reads, or applications
were run. The existing profile, provider, image/network settings, seats and SSH
ownership mode are preserved.

Before a real create/delete/start/stop, retain the legacy
`walter-liliana/walter-compute.tfstate`, inventory its owned resources and SSH key
registration, and review explicit mappings into library shared/node state and
its coordination journal under `walter-liliana/compute/`. The library refuses recognized
legacy state; never delete the old state or treat empty destination state as
absence of resources. Review for replacements and preserve development disk
contents. Keep destroy protection enabled. Power needs the backend and uses the
immutable ID from owned node state; desired instance-ID overrides are retired.

Managed keys are selected by absence of the provider SSH setting. Unowned key
collisions and missing owned key files refuse; delete never regenerates keys.
External mode preserves the existing provider key reference and creates no local
keypair. Only managed SSH config emits IdentityFile/IdentitiesOnly. The local
play migrates old Walter primary/seat markers atomically after ownership checks.
Root-login images bootstrap ubuntu; non-root logins retain their normalized user.

Build and focused convergence remain credential-free where documented. A real
create with github-account requires interactive device-flow approval, and clone
URLs use HTTPS. Do not pass ambient GITHUB_TOKEN to that approval workflow.

Validation: the actual installed published launcher completed build in a
separate temporary project using a sanitized environment. Its two compute
backend documents contained no credentials and shared/node provider documents
were present. This proves offline rendering, not live authentication, ownership
migration or machine health.

Configuration changes:

- Removed retired compute-keygen; prior value remains in Git history. Ownership comes from remote state, and SSH mode remains determined by setting presence.

The existing documentation says this machine was never created. That claim was
not reverified against live state. No existing-state guard was invented; the
library still refuses legacy state and unowned key collisions before creation.
