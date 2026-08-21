# walter-liliana

A remote development machine on Oracle Cloud, managed with
[walter](https://github.com/getcolors/walter).

```sh
./green build              # render .colors/walter-liliana/ — contacts nothing
./green create --dry-run   # print the graph — touches nothing
./green create             # provision it
ssh walter-liliana         # get on it
./green stop               # power off when you are done
./green start              # power on tomorrow
```

`colors.yml` is the only file you normally edit. Credentials never go in it —
they come from the gitignored `.envrc.private` as `COLORS_PAR_*` variables.

## Prerequisites

`direnv allow` brings up the toolchain through devenv: babashka, OpenTofu,
Ansible, the `oci` CLI, and the AWS CLI the R2 backend authenticates through.

`create` and `delete` need R2 credentials in `.envrc.private`:

```sh
export COLORS_PAR_R2_ACCESS_KEY_ID=...
export COLORS_PAR_R2_SECRET_ACCESS_KEY=...
```

OCI needs no variable — it authenticates from the `DEFAULT` profile in
`~/.oci/config`. That profile is session-token based and sessions last an hour;
when walter says it has expired, run what it tells you to.

## Status

**Not yet created.** Only `build` and `create --dry-run` have ever run here:
there is no instance, no remote state under `walter-liliana/`, no keypair, and
no ssh alias.

The desired machine is a `VM.Standard.A2.Flex` with 2 OCPU, 12 GB of memory and
a 100 GB boot volume in `xTQn:EU-FRANKFURT-1-AD-1` — the same tenancy
`walter-ada` uses, so a create draws on that tenancy's quota.

`oci-image-id` is pinned so a newer Canonical image cannot unexpectedly propose
a replacement. After the first create, add the resulting `oci-instance-id` to
`colors.yml` so `stop` and `start` work even when the R2 backend does not.

## What a create does

**It starts interactively, once.** `github-account` is set, so `create` prints a
one-time code and waits for you to approve it at
https://github.com/login/device. The machine gets its own GitHub login from
that token; every clone below authenticates https through it, and nothing of
this workstation's — no key, no forwarded agent — is involved. A machine already
logged in skips the step, so re-creates are unattended.

**Walter owns the ssh key.** `compute-keygen: true`, so `create` generates
`~/.ssh/walter-liliana` here if it is absent, authorizes it on the machine, and
pins the alias to it. Do not set `oci-ssh-authorized-keys` alongside it — the
build refuses the combination rather than silently overwriting your value. The
key file is named by the profile alone and is never regenerated over an existing
file, which is why the profile is named for the deployment.

**Then the machine.** nix, a Ghostty terminfo entry and the `cloudflared`
sysctls unconditionally; then Emacs from a pinned nixpkgs with the configuration
cloned to `~/.config/neoemacs`, every `getcolors` source repository under
`~/code/getcolors/`, and the `getcolors/dotfiles` checkout applied once through
its own Green launcher. Later creates preserve edits made on the machine.

`~/.config/neoemacs` is not a path Emacs reads on its own:

```sh
ssh walter-liliana
emacs --init-directory ~/.config/neoemacs
```

Emacs packages are fetched by a background job that outlives the create, so
`create` finishing is not the same as the packages being there:

```sh
ssh walter-liliana tail -f ~/.local/state/walter/emacs-packages.log
```

Everything else is `nix profile install` on the machine, not a change here.

See `CLAUDE.md` for the state isolation and operational safeguards.
