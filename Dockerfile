FROM node:22-trixie

RUN apt update && apt install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    locales \
    openssh-client \
    ripgrep \
    sudo \
    tmux \
    wget \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen

RUN curl -Lo /tmp/helix.deb https://github.com/helix-editor/helix/releases/download/25.07/helix_25.7.0-1_amd64.deb \
    && dpkg -i /tmp/helix.deb \
    && rm /tmp/helix.deb

RUN npm install -g pnpm typescript typescript-language-server vscode-langservers-extracted

RUN useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev

ENV CLAUDE_CONFIG_DIR=/home/dev/.claude

RUN mkdir -p /home/dev/.claude /home/dev/.ssh \
    && chown -R dev:dev /home/dev/.claude /home/dev/.ssh

COPY .gitconfig /home/dev/.gitconfig
COPY .bash_aliases /home/dev/.bash_aliases

RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/dev/.bashrc \
    && echo 'export EDITOR=hx' >> /home/dev/.bashrc \
    && echo 'export VISUAL=hx' >> /home/dev/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/dev/.bashrc \
    && echo '[ -f ~/.bash_aliases ] && . ~/.bash_aliases' >> /home/dev/.bashrc \
    && echo 'if [ -z "$SSH_AUTH_SOCK" ]; then eval "$(ssh-agent -s)" > /dev/null; ssh-add ~/.ssh/id_* 2>/dev/null; fi' >> /home/dev/.bashrc

ENV TMUX_THEME_COLOR="#ff8c00"
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN mkdir -p /workspace && chown dev:dev /workspace

USER dev

RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/dev/.local/bin:${PATH}"

WORKDIR /workspace

CMD ["bash"]
