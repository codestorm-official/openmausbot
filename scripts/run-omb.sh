#!/bin/sh
# Runs OpenMausBot as the unprivileged app user, with the ports and paths the
# in-container Caddy edge expects.
set -eu

# A bot's own dev server must not pick up the public edge's port.
unset PORT

export HOME=/data
export OMB_DATA_DIR=/data/.openmausbot
export OMB_PORT=8799
export OMB_WEBHOOK_PORT=8800

# A template reference that resolved to an empty domain leaves a bare scheme.
if [ "${OMB_PUBLIC_URL:-}" = "https://" ] || [ "${OMB_PUBLIC_URL:-}" = "http://" ]; then
  unset OMB_PUBLIC_URL
fi
if [ "${OMB_WEBHOOK_PUBLIC_URL:-}" = "https://" ] || [ "${OMB_WEBHOOK_PUBLIC_URL:-}" = "http://" ]; then
  unset OMB_WEBHOOK_PUBLIC_URL
fi
if [ -n "${OMB_PUBLIC_URL:-}" ]; then
  export OMB_PUBLIC_URL="${OMB_PUBLIC_URL%/}"
fi
if [ -z "${OMB_PUBLIC_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export OMB_PUBLIC_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
if [ -z "${OMB_WEBHOOK_PUBLIC_URL:-}" ] && [ -n "${OMB_PUBLIC_URL:-}" ]; then
  export OMB_WEBHOOK_PUBLIC_URL="${OMB_PUBLIC_URL}"
fi
if [ -z "${OMB_SERVER_NAME:-}" ]; then
  export OMB_SERVER_NAME="${RAILWAY_SERVICE_NAME:-OpenMausBot}"
fi

# Railway templates often carry optional key variables with empty defaults.
# OpenMausBot treats a set-but-empty key as "no key" and it would shadow the
# value saved in Settings, so remove empty ones before the server starts.
for name in BOX_TOKEN COMPOSIO_API_KEY OMB_ANTHROPIC_API_KEY OMB_OPENAI_API_KEY OMB_OPENROUTER_API_KEY XAI_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY KIMI_API_KEY MOONSHOT_API_KEY MINIMAX_API_KEY; do
  if [ -z "$(printenv "$name" 2>/dev/null || true)" ]; then
    unset "$name"
  fi
done

exec node /app/dist-server/server-launcher.js
