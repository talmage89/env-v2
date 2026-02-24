# cage

Containerized development environment with Claude Code, configurable network isolation, and user-extensible Docker builds.

Image and volume names are prefixed with `$USER` so multiple users on the same machine don't conflict.

## Setup

### Build

```sh
make build
```

This produces a Docker image named `$USER-cage`. When iterating on the image, prefer `make rebuild` — it removes the old image first to avoid accumulating dangling layers on disk.

### Shell Alias

Add to `~/.bash_aliases` or `~/.bashrc`:

```sh
alias cage='/path/to/env-v2/scripts/cage.sh'
```

### Configuration

```sh
cp defaults.conf.example defaults.conf
```

Edit `defaults.conf` to configure:

| Variable | Description | Default |
|---|---|---|
| `CAGE_PORTS` | Ports to forward (space-separated) | (none) |
| `CAGE_NETWORK` | Network profile | `claude` |
| `CAGE_GIT_PUSH_REMOTES` | Allowed git push URL patterns (space-separated) | (unrestricted) |
| `CAGE_CACHED_DIRS` | Workspace dirs stored in native volumes (bash array) | (none) |
| `CAGE_VOLUMES` | Volume mounts (bash array) | helix, tmux, claude config, ssh |

### Custom Dockerfile Extensions

```sh
cp user.Dockerfile.example user.Dockerfile
```

Add any `RUN`, `COPY`, or `ENV` instructions. These are injected into the Dockerfile during build (as root, before user creation) so you can install additional packages or tools.

## Usage

```sh
cage                    # start or attach (config defaults)
cage 8080 3000          # forward specific ports
cage --net none         # completely isolated (no network)
cage --net claude       # Claude Code + npm (default)
cage --net standard     # Claude + npm + GitLab
cage --net full 8080    # unrestricted + port forwarding
```

## Network Profiles

Network isolation prevents a prompt-injected agent from exfiltrating code to the public internet. The default profile (`claude`) allows only Anthropic API and package registry access.

| Profile    | Access                                |
|------------|---------------------------------------|
| `none`     | Completely isolated (no network stack)|
| `claude`   | Anthropic API + npm/yarn (default)    |
| `standard` | Claude + npm/yarn + GitLab            |
| `full`     | Unrestricted                          |

Profiles are defined in `network/profiles/` and are composable via `include` directives. Adding a new profile is as simple as creating a new `.profile` file.

Restricted profiles use iptables rules applied at container startup. IPv6 outbound is blocked to prevent leaks.

## Cached Directories

On macOS (Colima/virtiofs), file watching on bind-mounted directories is slow and CPU-heavy. Set `CAGE_CACHED_DIRS` to store specific workspace directories in native Docker volumes instead:

```sh
CAGE_CACHED_DIRS=("node_modules" ".next" "dist")
```

Each directory gets a named volume scoped to the project (by path hash), so different projects don't collide. These directories will be empty on first container creation — run `npm install` inside the container to populate them.

## Git Push Restriction

Set `CAGE_GIT_PUSH_REMOTES` in `defaults.conf` to restrict which remotes `git push` can reach inside the container:

```sh
CAGE_GIT_PUSH_REMOTES="gitlab.com/myorg/myrepo"
```

A global pre-push hook blocks pushes to any remote URL not matching a configured pattern. Leave empty to allow all remotes.

## Lifecycle

The container runs in the background and survives broken pipes and terminal closures.

- **`exit`** or close terminal — leaves the container running
- **`cage`** — opens a new shell in the running container
- **`docker stop $(docker ps -q -f ancestor=$USER-cage)`** — stop the container
- **`docker rm $(docker ps -aq -f ancestor=$USER-cage)`** — remove a stopped container

## Repository Structure

```
├── scripts/           host-side scripts (cage.sh, build.sh)
├── config/            copied to /home/cage/ in the container
├── network/
│   ├── profiles/      network profile definitions (.profile files)
│   ├── entrypoint.sh  container entrypoint (applies firewall)
│   └── apply-firewall.sh
├── defaults.conf      local config (gitignored)
└── user.Dockerfile    personal Dockerfile extensions (gitignored)
```
