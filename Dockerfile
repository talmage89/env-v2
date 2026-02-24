FROM node:22-trixie

RUN apt update && apt install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    iptables \
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

RUN npm install -g pnpm typescript typescript-language-server vscode-langservers-extracted

# === USER EXTENSIONS ===
# === END USER EXTENSIONS ===

RUN userdel -r node \
    && useradd -m -s /bin/bash -u 1000 cage \
    && echo "cage ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cage

ENV CLAUDE_CONFIG_DIR=/home/cage/.claude

RUN mkdir -p /home/cage/.claude /home/cage/.ssh \
    && chown -R cage:cage /home/cage/.claude /home/cage/.ssh

COPY config/ /home/cage/

RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/cage/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/cage/.bashrc \
    && echo '[ -f ~/.bash_aliases ] && . ~/.bash_aliases' >> /home/cage/.bashrc \
    && echo 'if [ -z "$SSH_AUTH_SOCK" ]; then eval "$(ssh-agent -s)" > /dev/null; ssh-add ~/.ssh/id_* 2>/dev/null; fi' >> /home/cage/.bashrc

ENV TMUX_THEME="#ff8c00"
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

COPY network/profiles/ /etc/cage-network/profiles/
COPY network/apply-firewall.sh /etc/cage-network/apply-firewall.sh
COPY network/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /etc/cage-network/apply-firewall.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /workspace && chown cage:cage /workspace

USER cage

RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/cage/.local/bin:${PATH}"

WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
