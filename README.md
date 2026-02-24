# cage

Containerized development environment with Claude Code, configurable network isolation, and user-extensible Docker builds.

## Setup

### Build

```sh
make build
```

### Shell Alias

Add to `~/.bash_aliases` or `~/.bashrc`:

```sh
alias cage='/path/to/env-v2/scripts/cage.sh'
```

### Configuration

```sh
cp defaults.conf.example defaults.conf
```

Edit `defaults.conf` to set default ports, network profile, and volume mounts.

### Custom Dockerfile Extensions

```sh
cp user.Dockerfile.example user.Dockerfile
```

Add any `RUN`, `COPY`, or `ENV` instructions. These are injected into the Dockerfile during build (as root, before cage user creation) so you can install additional packages or tools.

## Usage

```sh
cage                    # start or attach (config defaults)
cage 8080 3000          # forward specific ports
cage --net none         # completely isolated (no network)
cage --net claude       # Claude Code API only
cage --net standard     # Claude + npm + GitLab
cage --net full 8080    # unrestricted + port forwarding
```

## Network Profiles

| Profile      | Access                                          |
|--------------|-------------------------------------------------|
| `none`       | Completely isolated (no network stack)           |
| `claude`     | Claude Code API only                             |
| `standard`   | Claude + npm/yarn + GitLab                       |
| `full`       | Unrestricted (default)                           |

Profiles are defined in `network/profiles/` and are composable via `include` directives. Adding a new profile is as simple as creating a new `.profile` file.

## Lifecycle

The container runs in the background and survives broken pipes and terminal closures.

- **`exit`** or close terminal — leaves the container running
- **`cage`** — opens a new shell in the running container
- **`docker stop $(docker ps -q -f ancestor=cage)`** — stop the container
- **`docker rm $(docker ps -aq -f ancestor=cage)`** — remove a stopped container

## Repository Structure

```
├── scripts/           host-side scripts (cage.sh, build.sh)
├── config/            copied to /home/cage/ in the container
├── network/
│   ├── profiles/      network profile definitions
│   ├── entrypoint.sh  container entrypoint (applies firewall)
│   └── apply-firewall.sh
├── defaults.conf      local config (gitignored)
└── user.Dockerfile    personal Dockerfile extensions (gitignored)
```
