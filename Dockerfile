# OpenMausBot on Railway.
#
# The official server image (harness server, web app and the bots' browser)
# is used unchanged. This image adds:
#   - Claude Code and Codex, pinned, because the published server image ships
#     no engine CLIs;
#   - Caddy as the only public listener, copied from the official Caddy image;
#   - a small entrypoint that repairs the /data volume, runs OpenMausBot as
#     `maus` and Caddy as a separate unprivileged user, and stops the
#     container when either process exits.
#
# OpenMausBot stays on 127.0.0.1:8799/8800 inside the container, as upstream
# documents: its loopback port is the owner trust boundary. Caddy reaches it
# over loopback and marks every forwarded request as proxied.

FROM caddy:2.10.2@sha256:c3d7ee5d2b11f9dc54f947f68a734c84e9c9666c92c88a7f30b9cba5da182adb AS edge
# Copying to a new inode drops the image's cap_net_bind_service; the edge uses
# an unprivileged port.
RUN cp /usr/bin/caddy /caddy

FROM ghcr.io/milind-soni/openmausbot:v0.1.175@sha256:953a4ce2f34d4bf981a8635f51e5cb07ee66dd37c6a12714fe838329b0989dde

USER root

# Engine CLIs. The published image has ENGINES empty; upstream's own Compose
# setup bakes these in the same way. PIN_ prefix so Railway service variables
# cannot collide with a CLI's own settings.
ARG PIN_CLAUDE_CODE=2.1.323
ARG PIN_CODEX=0.171.0
RUN export HOME=/tmp/omb-build-home \
 && npm install -g --no-fund --no-audit --cache /tmp/omb-npm-cache \
      "@anthropic-ai/claude-code@${PIN_CLAUDE_CODE}" \
      "@openai/codex@${PIN_CODEX}" \
 && DISABLE_AUTOUPDATER=1 claude --version \
 && codex --version \
 && rm -rf /tmp/omb-build-home /tmp/omb-npm-cache /tmp/node-compile-cache

COPY --from=edge /caddy /usr/local/bin/caddy
COPY conf/Caddyfile /etc/caddy/Caddyfile
COPY scripts/start.sh scripts/run-omb.sh scripts/omb /usr/local/bin/

# Caddy runs as its own user: it can read its config, but not /data, engine
# logins or bot files. OpenMausBot and every bot shell run as the image's
# unprivileged `maus` user.
RUN set -eu; \
    useradd --system --create-home --home-dir /tmp/caddy --shell /usr/sbin/nologin caddy; \
    mkdir -p /tmp/caddy/data /tmp/caddy/config; \
    chown -R caddy:caddy /tmp/caddy; \
    chmod 0755 /usr/local/bin/start.sh /usr/local/bin/run-omb.sh /usr/local/bin/omb /usr/local/bin/caddy; \
    chmod 0644 /etc/caddy/Caddyfile; \
    bash -n /usr/local/bin/start.sh; \
    sh -n /usr/local/bin/run-omb.sh; \
    sh -n /usr/local/bin/omb; \
    test -x /usr/bin/tini; \
    test -x /usr/bin/setpriv; \
    test -f /app/dist-server/server-launcher.js; \
    test -f /app/dist-server/openmausbot.js; \
    test -f /app/dist/index.html; \
    test "$(id -u maus)" != 0; \
    test "$(id -u caddy)" != 0; \
    HOME=/tmp/caddy-check XDG_DATA_HOME=/tmp/caddy-check XDG_CONFIG_HOME=/tmp/caddy-check PORT=8080 \
      caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; \
    rm -rf /tmp/caddy-check

ENV DISABLE_AUTOUPDATER=1 \
    PORT=8080 \
    OMB_CLI_PREFIX="omb"

EXPOSE 8080

# tini is PID 1 so exited engines, browsers and shell commands are collected.
# start.sh runs OpenMausBot and Caddy as separate users and exits the
# container if either one stops.
ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/usr/local/bin/start.sh"]
CMD []
