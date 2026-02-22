# dev env

## Build

```sh
docker build -t dev-env .
```

## Shell Function

Add this to your `~/.bash_aliases` to launch the container from any project directory:

```sh
dev() {
  # Running? Exec into it.
  local running
  running=$(docker ps -q -f ancestor=dev-env | head -1)
  if [ -n "$running" ]; then
    docker exec -it "$running" bash
    return
  fi

  # Stopped? Restart it, then exec.
  local stopped
  stopped=$(docker ps -aq -f ancestor=dev-env -f status=exited | head -1)
  if [ -n "$stopped" ]; then
    docker start "$stopped"
    docker exec -it "$stopped" bash
    return
  fi

  # New container (detached), then exec in.
  local args=("$@")
  if [ ${#args[@]} -eq 0 ]; then
    args=(3000)
  fi
  local ports=()
  for port in "${args[@]}"; do
    ports+=(-p "$port:$port")
  done
  local id
  id=$(docker run -dit \
    "${ports[@]}" \
    -v "$PWD":/workspace \
    -v "$HOME/.config/helix":/home/dev/.config/helix:ro \
    -v "$HOME/.config/tmux":/home/dev/.config/tmux:ro \
    -v claude-config:/home/dev/.claude \
    -v claude-ssh:/home/dev/.ssh \
    dev-env)
  docker exec -it "$id" bash
}
```

## Usage

```sh
dev              # exec into running/stopped container, or start with port 3000 forwarded
dev 5173         # start with port 5173 instead of the default
dev 3000 5173    # start with multiple ports forwarded
```

## Lifecycle

The container runs in the background and survives broken pipes and terminal closures.

- **`exit`** or close terminal — leaves the container running
- **`dev`** — opens a new shell in the running container
- **`docker stop $(docker ps -q -f ancestor=dev-env)`** — stop the container when done
- **`docker rm $(docker ps -aq -f ancestor=dev-env)`** — remove a stopped container
