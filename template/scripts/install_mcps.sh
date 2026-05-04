#!/bin/bash
# SAM MCP installer — runs after credential setup.
# Reads $HOME/.sam/credentials.env (created interactively during bootstrap)
# and registers each MCP server with Claude Code.
#
# Usage: bash install_mcps.sh

set -euo pipefail

CRED_FILE="$HOME/.sam/credentials.env"
if [ ! -f "$CRED_FILE" ]; then
  echo "ERROR: $CRED_FILE not found. Run credential setup first."
  exit 1
fi

# shellcheck disable=SC1090
source "$CRED_FILE"

echo "════════════════════════════════════════════════════════════════"
echo "  Registering MCP servers with Claude Code"
echo "════════════════════════════════════════════════════════════════"

# ---------- Shopify Admin (HTTP) ----------
if [ -n "${SHOPIFY_STORE_DOMAIN:-}" ] && [ -n "${SHOPIFY_ADMIN_TOKEN:-}" ]; then
  echo "[1/5] Shopify Admin → ${SHOPIFY_STORE_DOMAIN}"
  claude mcp remove shopify 2>/dev/null || true
  claude mcp add --transport http shopify \
    "https://${SHOPIFY_STORE_DOMAIN}/admin/api/2025-01/graphql.json" \
    --header "X-Shopify-Access-Token: ${SHOPIFY_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    --scope user
else
  echo "[1/5] Shopify: skipped (SHOPIFY_STORE_DOMAIN or SHOPIFY_ADMIN_TOKEN missing)"
fi

# ---------- Postiz (HTTP) ----------
if [ -n "${POSTIZ_API_KEY:-}" ]; then
  echo "[2/5] Postiz"
  claude mcp remove postiz 2>/dev/null || true
  claude mcp add --transport http postiz \
    "https://api.postiz.com/public/v1/mcp" \
    --header "Authorization: Bearer ${POSTIZ_API_KEY}" \
    --scope user
else
  echo "[2/5] Postiz: skipped (POSTIZ_API_KEY missing)"
fi

# ---------- Google Workspace (claude.ai connectors — auth in browser) ----------
echo "[3/5] Google Workspace: Gmail / Calendar / Drive use claude.ai connectors."
echo "      Open Claude Code, run: /mcp"
echo "      Authenticate Gmail, Calendar, Drive when prompted."

# ---------- Telegram plugin ----------
echo "[4/5] Telegram: install via plugin marketplace."
echo "      Open Claude Code, run: /plugins"
echo "      Install 'telegram' from claude-plugins-official."
echo "      After install, run: /telegram:setup"
echo "      Use bot token: ${TELEGRAM_BOT_TOKEN:-<set TELEGRAM_BOT_TOKEN in credentials.env>}"

# ---------- Filesystem (project scope, points at client folder) ----------
CLIENT_SLUG="${CLIENT_SLUG:-}"
if [ -n "$CLIENT_SLUG" ]; then
  CLIENT_DIR="$HOME/.sam/sam-deployments/clients/$CLIENT_SLUG"
  echo "[5/5] Filesystem MCP → $CLIENT_DIR"
  claude mcp remove filesystem 2>/dev/null || true
  claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem "$CLIENT_DIR" \
    --scope user
else
  echo "[5/5] Filesystem: skipped (CLIENT_SLUG not set)"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  MCP registration complete. Verify with: claude mcp list"
echo "════════════════════════════════════════════════════════════════"
