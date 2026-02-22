# dev env

## Build

```sh
docker build -t dev-env .
```

## Run

```sh
docker run -it --rm \
    -v "$PWD":/workspace \
    -v "$HOME/.config/helix":/home/dev/.config/helix:ro \
    -v "$HOME/.config/tmux":/home/dev/.config/tmux:ro \
    -v claude-config:/home/dev/.claude \
    -v claude-ssh:/home/dev/.ssh \
    dev-env
```

## Shell Function

Add this to your `~/.bash_aliases` to launch the container from any project directory:

```sh
dev() {
  local existing
  existing=$(docker ps -q -f ancestor=dev-env)
  if [ -n "$existing" ]; then
    docker attach "$existing"
  else
    local args=("$@")
    if [ ${#args[@]} -eq 0 ]; then
      args=(3000)
    fi
    local ports=()
    for port in "${args[@]}"; do
      ports+=(-p "$port:$port")
    done
    docker run -it --rm \
      "${ports[@]}" \
      -v "$PWD":/workspace \
      -v "$HOME/.config/helix":/home/dev/.config/helix:ro \
      -v "$HOME/.config/tmux":/home/dev/.config/tmux:ro \
      -v claude-config:/home/dev/.claude \
      -v claude-ssh:/home/dev/.ssh \
      dev-env
  fi
}
```

## Usage

```sh
dev              # attach to running container, or start with port 3000 forwarded
dev 5173         # start with port 5173 instead of the default
dev 3000 5173    # start with multiple ports forwarded
```

## Detach / Reattach

- **`Ctrl+P, Ctrl+Q`** — detach without stopping the container
- **`dev`** — reattach to the running container
