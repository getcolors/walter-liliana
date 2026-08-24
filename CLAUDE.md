# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## What this repository is

Desired state for `walter-liliana`: one Oracle Cloud development machine,
OpenTofu state in Cloudflare R2. Nothing here is source code. What is tracked is
`colors.yml`, the installed launcher, the skill package behind it, and the
dev-environment files.

```text
colors.yml                        the desired state — the only file you normally edit
green                             the installed launcher (a COPY of the payload)
.agents/skills/package-walter-green   the installed skill package
.claude/skills/package-walter-green   a symlink into .agents/skills, so Claude Code finds it
.envrc                            secret-free; sources the gitignored .envrc.private
devenv.nix                        the toolchain
```

Everything else is generated (`.colors/`) or secret (`.envrc.private`).
`.gitignore` is `.*` with narrow negations, so check `git ls-files` rather than
assuming from the working tree.

## Commands

```sh
./green build              # render .colors/walter-liliana/ — contacts nothing
./green create --dry-run   # print the graph — touches nothing
./green create             # provision, and write the ssh alias
./green stop               # power off
./green start              # power on, and refresh the alias
./green delete             # destroy (guarded — see below)
```

## This machine has never been created

As of scaffolding, `./green build` and `./green create --dry-run` are the only
verbs that have ever run here. There is no instance, no R2 state under
`walter-liliana/`, no generated keypair, and no `~/.ssh/config` block. Do not
describe the machine in the present tense until a real `create` has succeeded.

`oci-instance-id` is deliberately absent for the same reason — see the gotcha
below.

## How this deployment differs from walter-oci and walter-ada

The two older Walters were created against an earlier pin and their own
`CLAUDE.md` files describe that behaviour. **Do not carry their claims over.**
This deployment is on a pin where three things changed:

- **Walter generates the machine-access keypair.** `compute-keygen: true`, so
  `create` writes `~/.ssh/walter-liliana` and `.pub` on this workstation if
  absent, feeds the public half to OCI, and pins the alias to it with
  `IdentityFile` + `IdentitiesOnly`. `oci-ssh-authorized-keys` is walter's to
  derive — setting it in `colors.yml` is refused, not overwritten. The older two
  supply `~/.ssh/id_ed25519.pub` by hand instead.
- **The machine holds its own GitHub identity.** `github-account` + `git-email`
  mint a token by device flow, and every clone authenticates https through it.
- **There is no agent forwarding anywhere.** Nothing on the machine
  authenticates with this workstation's keys.

### The keypair is named by the profile alone

`~/.ssh/walter-liliana`, with no prefix. That is why the profile is named for
the deployment: **an existing key file is never regenerated**, so a profile
colliding with a key already in `~/.ssh` would silently adopt it and authorize a
personal key on the machine rather than minting a new one. Nothing warns.

The file survives `delete` on purpose — a keypair is not provider state, and the
next `create` of this profile adopts it rather than churning OCI's key registry.

### The GitHub identity is interactive, once, at the start

With `github-account` set, a real `create` begins by printing a one-time code and
waiting — up to about fifteen minutes — for approval at
https://github.com/login/device. That is the design, not a hang: the workflow is
interactive at the beginning only. Relay the code and URL rather than assuming a
stall.

The token is sandboxed into `~/.local/state/walter/github-token-walter-liliana`
and stashed in opts as a **file path**, never as the token itself. A create that
fails part-way keeps the sandbox deliberately, so the retry reuses the surviving
token instead of asking for a second code. A machine already logged in skips the
step entirely, so re-creates stay unattended.

Deleting the machine does not revoke the token — GitHub Settings → Applications
→ GitHub CLI does.

**Run `create` from a shell with no ambient `GITHUB_TOKEN`.** Before starting
the device flow, walter probes the sandbox with `gh auth status` and
`gh api user -q .login`, and reuses the login when the name matches
`github-account`. `gh` falls back to `GITHUB_TOKEN` from the environment when
the config dir has no token of its own — and the workspace root
`~/code/getcolors/.envrc` exports exactly that. Both probes then succeed and
return `amiorin`, which matches, so walter takes the reuse branch and seeds the
machine with the **workspace PAT** instead of minting a device-flow token.

Verified at the probe level against the empty sandbox: `gh auth status` succeeds
and `gh api user -q .login` answers `amiorin` with `GH_CONFIG_DIR` pointing at a
directory containing nothing. What follows from that — walter's reuse branch —
is read from `github.clj`, not observed end to end.

It matters because the scopes differ. The device flow asks for `workflow`; that
PAT carries `repo` and `read:org`, so a machine seeded this way would be quietly
unable to push workflow files, with nothing in the create's output saying so.

`direnv exec .` from this directory is safe — walter-liliana's `.envrc` does not
source the workspace root's, so `GITHUB_TOKEN` is absent. A shell that has cd'd
through `~/code/getcolors` with direnv hooked is **not** safe. Check before
starting:

```sh
echo "[${GITHUB_TOKEN-unset}]"    # must print [unset]
```

## What the machine gets

The remote stage installs **nix**, a **Ghostty terminfo entry**, and kernel
networking settings for unprivileged `cloudflared` on any walter machine. Then,
because `emacs-config-repo` is set, Emacs from a pinned nixpkgs plus the
configuration cloned to `~/.config/neoemacs`:

```sh
ssh walter-liliana
emacs --init-directory ~/.config/neoemacs
```

The `--init-directory` is mandatory. `~/.config/neoemacs` is not a path Emacs
looks in on its own; the XDG default it *does* read is `~/.config/emacs`, and
this configuration deliberately does not live there.

`TERM` travels over SSH and the terminfo database does not, which is why the
terminfo entry is there. Without it Ubuntu has never heard of Ghostty and answers
every full-screen program — `vim`, `top`, `less`, Emacs — with `Terminal type
xterm-ghostty is not defined`. If that error ever appears, the fix is to re-run
`create`, not to change `TERM`.

Two things about the Emacs clone, in the order they will bite:

- **It happens once.** A later `create` leaves an existing checkout alone. That
  is on purpose: this is a working copy on a development machine, and an apply
  must not discard edits made there. `git pull` on the machine is how it moves.
- **Packages are fetched in the background by `create`, not on first launch.**
  The final `walter-emacs-packages` stage starts `emacs --batch -l init.el` and
  does **not** wait: the job is daemonized, so it outlives the play, the SSH
  connection and the create itself. `create` finishing is therefore not the same
  as the packages being there — this is true nowhere else in the workflow.

  ```sh
  ssh walter-liliana tail -f ~/.local/state/walter/emacs-packages.log
  ```

  It cannot fail a `create`; nothing waits on it. That log is the only diagnostic
  there is. Tree-sitter grammars are **not** covered — this configuration
  installs them lazily when a mode first loads — and `nerd-icons-install-fonts`
  remains a manual step.

`nix` and `emacs` arrive on `PATH` through `/etc/profile.d/nix.sh`, which is a
**login** shell mechanism. `ssh walter-liliana` sees them; `ssh walter-liliana
emacs …` as a one-shot command does not.

`nix profile add` runs with `NIXPKGS_ALLOW_UNFREE=1` and `--impure` so unfree
attributes (`claude-code`) install beside free ones in one invocation. The cost
is that the licence check is relaxed for the whole list.

Anything else you want on the machine is `nix profile install` there, not a
change to this repository.

## The org checkouts

`clone-orgs: [getcolors]` puts every source repository in the org under
`~/code/getcolors/<repo>` on the machine — the same layout this workstation
uses, so a path that works here works there.

Only the org name is in `colors.yml`. The list is read from GitHub's API **on
the machine at create time**, through the machine's own gh login
(`gh api --paginate --slurp`), so it sees what the account sees — private
repositories included — and complete organisations of any size. A repository
added upstream arrives on the next `create` with nothing here to edit, and
equally nothing here records the resolved list. Forks are dropped by the API's
`type=sources`; archived repositories are skipped with a `when:`, so the run
names what it passed over.

Like the Emacs clone, these **happen once** — a later `create` leaves existing
checkouts alone, so work done on the machine survives — and they are the longest
part of a create.

After them, `dotfiles-checkout: ~/code/getcolors/dotfiles` runs that checkout's
own `./green create` with its own `colors.yml`, which selects the Ubuntu profile
and targets `$HOME`. Walter supplies only
`COLORS_PAR_DOTFILES_PREVENT_OVERWRITE=false` and stamps success under
`~/.local/state/walter`, so later creates do not reapply files over edits made on
the machine. Walter never exports `COLORS_PAR_PROFILE`.

## Seeded agent credentials

`seed-agent-credentials: [claude, codex, pi]` copies **one credential file per
agent** from this workstation, never the directory around it — those directories
are mostly session transcripts. The guard is `force: false`, so it will not
clobber a login made on the machine directly. These are OAuth refresh tokens
rotated in place, so both overwrites matter.

Claude Code has one non-credential companion: interactive startup checks
`hasCompletedOnboarding` in `~/.claude.json` separately, and otherwise shows
login methods even while `claude auth status` recognizes the copied tokens. The
playbook atomically adds that key as `true` only if absent, and never copies this
workstation's own `~/.claude.json`.

## State isolation

This project shares the OCI tenancy, compartment and subnet with `walter-ada`,
and shares the R2 state bucket with every other deployment. What separates it is
the **profile**: remote state is keyed `<profile>/<stage>.tfstate`, so this
project writes `walter-liliana/walter-compute.tfstate`, and the stage is named
`walter-compute` rather than `tofu-compute` so a colliding profile still cannot
address another package's state.

Because the tenancy is shared with `walter-ada`, a create here consumes that
tenancy's quota. Two `VM.Standard.A2.Flex` machines at 2 OCPU / 12 GB each is
what this implies; a quota refusal at create time is a quota problem, not a
walter bug.

**Never export `COLORS_PAR_PROFILE`.** `profile` is a flat key and `COLORS_PAR_*`
overlays any flat key, so an environment override could point walter at another
deployment's state in the shared bucket. Walter refuses to start when it is set.
Do not suggest a workaround; that is the guard working.

## OCI credentials

The `DEFAULT` profile is session-token based, so `.envrc` exports
`OCI_CLI_AUTH=security_token` — the `oci` CLI rejects that profile otherwise.
OpenTofu's `oracle/oci` provider detects `security_token_file` by itself and does
not need the variable.

That asymmetry matters because **walter's everyday verbs drive the CLI**. `stop`
and `start` never reach OpenTofu — power state is not desired state — so they
depend on a live session where `create` does not. Sessions last 60 minutes.

The fix is the `refresh-oci-token` Agent Skill. It is **not** installed under
`~/.claude/skills` on this machine, whatever `walter-ada/CLAUDE.md` says — it
lives in the workspace `skills/` checkout, and the script is run relative to its
`SKILL.md`:

```sh
cd ~/code/getcolors/skills/refresh-oci-token && bb refresh-oci-token.clj
```

Within a session's window it extends the token in place with no browser. A fully
expired session needs the login flow, which transfers the URL through the Emacs
kill ring rather than printing it — so it is the operator's to run, not an
agent's. Do not fall back to bare `oci session authenticate`; that prints the
login URL to the terminal instead.

Note that an expired session does not always announce itself as one. Without
`OCI_CLI_AUTH=security_token` the CLI rejects the profile under its default
ApiKey auth and reports `user missing`, which reads like a broken config. With
the variable set the real message is `This CLI session has expired`. `.envrc`
exports it, so this only bites outside a direnv-loaded shell.

## Gotchas

**The root `green` is a copy, not a symlink.** Re-copy it after any payload
update or the project keeps running the old pin:

```sh
cp .agents/skills/package-walter-green/green green
```

**`stop` does not restart with `create`.** With no power state in the
configuration there is no diff, so an apply leaves a stopped machine stopped.
`start` is the only way up.

**Fill in `oci-instance-id` once it exists**, and again after every recreate — it
names one instance, so a rebuilt machine leaves it pointing at a `TERMINATED`
one. It is what makes `stop` and `start` work when the R2 backend is unreachable,
rather than leaving you with a running machine you cannot power off.

**`oci-image-id` is already pinned**, to the same Canonical image the other two
Walters use. Leaving it unset would take the newest compatible image, and the
image id forces replacement — so a later apply would propose destroying the
machine because Canonical published something new. With
`compute-prevent-destroy: true` that apply fails instead, which is safe and
confusing.

**Changes in `../walter` are inert until the pin moves.** `colors.yml` keys are
read by a playbook that lives in the library the root `./green` resolves by SHA,
so `./green build` renders the pinned playbook, not the working tree's. To see
the working tree meanwhile — a deliberate act, rendering something the pinned
launcher would not run:

```sh
WALTER_LIB_ROOT=../walter ./green build
```

**Running `tofu` by hand needs the R2 keys passed in.** On its own it fails with

```text
Failed to load state: … InvalidArgument: Credential access key has length 20, should be 32
```

Nothing is wrong with the bucket. `AWS_ACCESS_KEY_ID` is unset in the shell, so
the AWS SDK falls through its default chain to `~/.aws/credentials` and offers
OpenTofu an unrelated Amazon key. Walter never hits this because it passes the R2
credentials to every stage explicitly; only the by-hand path is exposed:

```sh
cd .colors/walter-liliana/walter-compute
AWS_ACCESS_KEY_ID="$COLORS_PAR_R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$COLORS_PAR_R2_SECRET_ACCESS_KEY" \
  tofu output -raw instance_id
```

**A recreate brings a new host key, and a new address.** The managed
`~/.ssh/config` block is rewritten with the new IP, but nothing touches
`~/.ssh/known_hosts` — so the first `ssh walter-liliana` afterwards asks you to
accept an unknown host. Under `BatchMode=yes` or with no terminal the same
situation is reported as `Host key verification failed`, which reads like a stale
entry rather than a missing one. To record it without a prompt:

```sh
ssh -o StrictHostKeyChecking=accept-new walter-liliana true
```

The remote Ansible stage never hits this — `ansible.cfg` sets
`StrictHostKeyChecking=no` and points `UserKnownHostsFile` at `/dev/null`.

**Outputs' `ip` is authoritative only immediately after an apply.** An
out-of-band power cycle does not refresh OpenTofu state, so the stored address
can be stale. `start` reads the address live from OCI for exactly this reason.

**`delete` takes the boot volume with it.** This is a development machine; what
is on it is uncommitted work. The guard is on by default and lifted with
`COLORS_PAR_COMPUTE_PREVENT_DESTROY=false` for one intentional run.

## Provenance

The launcher here is pinned and self-resolving: `./green` fetches
`io.github.getcolors/walter` at the stamped commit on first run, into
`~/.gitlibs`, and needs no checkout, no `WALTER_LIB_ROOT` and no install step.

It was **copied by hand** from `../walter/skills/package-walter-green/`, not
installed with `npx skills add getcolors/walter`, so there is deliberately no
`skills-lock.json` — a lockfile records the source and content hash that an
actual install computed, and writing one by hand would be a claim this project
did not earn. This matches `walter-oci`, `walter-ada`, `clickhouse-hetzner` and
`alice-digitalocean`; the ONCE deployments differ because they were really
installed. Run the real install when you want it:

```sh
npx skills add getcolors/walter
cp .agents/skills/package-walter-green/green green    # the copy, again
```

## Documentation

`index.html` is this repository's landing page and carries two analytics tags:
GA4 measurement ID `G-4VKP1WY4QJ`, whose explicit `page_title` must exactly
equal the decoded HTML `<title>` and stay distinct and stable so one Analytics
property can separate repositories, and the self-hosted Rybbit snippet
`<script src="https://rybbit.getcolors.ai/api/script.js" data-site-id="9fb9c41a6d49" defer></script>`,
which shares one site ID across every page because `getcolors.github.io/<repo>/`
paths already encode the repository. Never add one tag without the other.

## Git

Do not commit or push unless explicitly asked.
