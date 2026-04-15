#!/bin/bash
# Agent Control Script
# Usage: agentctl.sh <command> [args]
#
# Commands:
#   create <name> <token> <api_key> [size_mb] - Create and start new agent
#   start <name> [size_mb]  - Start agent (default: 100MB disk limit)
#   stop <name>             - Stop agent
#   restart <name>          - Restart agent
#   status [name]           - Show status (all or specific)
#   list                    - List all agents
#   delete <name>           - Delete agent and container
#
# Examples:
#   agentctl.sh create newbot <token> <api_key> 500
#   agentctl.sh start runner 500     # 500MB limit
#   agentctl.sh start tester        # 100MB default limit
#   agentctl.sh status runner
#   agentctl.sh list

set -e

cmd="$1"
HOST="${SSH_HOST:-srv}"
AGENTS_DIR="$HOME/picoclaw-agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/agent_config.template.json"

# Load .env if exists
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Default disk limit in MB
DEFAULT_SIZE_MB=100

# Default user chat ID
DEFAULT_USER_CHAT_ID="141455495"

sshsrv() {
    ssh "$HOST" "$@"
}

start_agent() {
    local agent="$1"
    local limit="${2:-$DEFAULT_SIZE_MB}"

    echo "Starting agent '$agent' with ${limit}MB disk limit..."

    sshsrv "
        cd $AGENTS_DIR/$agent

        # Stop existing container
        docker rm -f picoclaw-$agent 2>/dev/null || true

        # Run with storage limit
        # Note: picoclaw reads /root/.picoclaw/config.json - mount dir so config.json is at that path
        docker run -d \
            --name picoclaw-$agent \
            --restart unless-stopped \
            --memory=64m \
            --cpus=0.25 \
            --storage-opt size=${limit}M \
            --add-host=host.docker.internal:host-gateway \
            -v $AGENTS_DIR/$agent:/root/.picoclaw:rw \
            -e HTTPS_PROXY=http://host.docker.internal:10808 \
            -e HTTP_PROXY=http://host.docker.internal:10808 \
            -e no_proxy='*' \
            ghcr.io/sipeed/picoclaw:latest

        echo 'Started. Recent logs:'
        docker logs picoclaw-$agent --tail 5
    "
}

stop_agent() {
    local agent="$1"
    echo "Stopping agent '$agent'..."
    sshsrv "docker rm -f picoclaw-$agent"
}

restart_agent() {
    local agent="$1"
    echo "Restarting agent '$agent'..."
    sshsrv "docker restart picoclaw-$agent"
}

status_agent() {
    local agent="$1"
    sshsrv "docker ps -a --filter name=picoclaw-$agent --format 'table {{.Names}}\t{{.Status}}\t{{.Size}}'"
}

list_agents() {
    echo "=== PicoClaw Agents ==="
    sshsrv "docker ps -a --filter 'name=picoclaw-' --format 'table {{.Names}}\t{{.Status}}\t{{.Size}}'"
}

delete_agent() {
    local agent="$1"
    echo "Deleting agent '$agent'..."
    sshsrv "docker rm -f picoclaw-$agent"
    echo "Container removed. Config preserved at $AGENTS_DIR/$agent/"
}

create_agent() {
    local agent="$1"
    local token="$2"
    local user_chat_id="${3:-$DEFAULT_USER_CHAT_ID}"
    local limit="${4:-$DEFAULT_SIZE_MB}"
    local omniroute_admin_key="${OMNIROUTE_ADMIN_KEY:-}"

    if [[ -z "$agent" || -z "$token" ]]; then
        echo "Error: name and telegram_token required"
        echo "Usage: agentctl.sh create <name> <telegram_token> [user_chat_id] [size_mb]"
        exit 1
    fi

    if [[ -z "$omniroute_admin_key" ]]; then
        echo "Error: OMNIROUTE_ADMIN_KEY not set in .env file"
        exit 1
    fi

    if [[ ! -f "$TEMPLATE" ]]; then
        echo "Error: template not found at $TEMPLATE"
        exit 1
    fi

    echo "Creating agent '$agent' with ${limit}MB disk limit..."

    # Create OmniRoute API key first
    echo "Creating OmniRoute API key..."
    local omniroute_response
    omniroute_response=$(curl -s -X POST "http://62.106.66.13:3000/api/keys" \
        -H "Authorization: Bearer $omniroute_admin_key" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$agent\"}")
    
    local agent_api_key
    agent_api_key=$(echo "$omniroute_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null)
    
    if [[ -z "$agent_api_key" ]]; then
        echo "Error: Failed to create OmniRoute key. Response: $omniroute_response"
        exit 1
    fi
    
    echo "OmniRoute key created: $agent_api_key"

    # Create config on srv from template
    # Note: Remote paths are fixed - deploy directory on srv
    sshsrv "
        DEPLOY_DIR=/home/openclaw/picoclaw-agents/deploy
        mkdir -p $AGENTS_DIR/$agent
        chmod 755 $AGENTS_DIR/$agent

        # Copy template and replace placeholders
        sed -e 's/{{TELEGRAM_TOKEN}}/$token/g' \
            -e 's/{{API_KEY}}/$agent_api_key/g' \
            -e 's/{{USER_CHAT_ID}}/$user_chat_id/g' \
            '\$DEPLOY_DIR/agent_config.template.json' > $AGENTS_DIR/$agent/config.json

        chmod 600 $AGENTS_DIR/$agent/config.json

        # Copy workspace templates
        if [ -d '\$DEPLOY_DIR/templates' ]; then
            cp -r '\$DEPLOY_DIR/templates/'* $AGENTS_DIR/$agent/
            # Replace agent name placeholder
            for f in $AGENTS_DIR/$agent/*.md; do
                sed -i 's/{{AGENT_NAME}}/$agent/g' "\$f" 2>/dev/null || true
            done
        fi

        # Copy skills
        if [ -d '\$DEPLOY_DIR/skills' ]; then
            mkdir -p $AGENTS_DIR/$agent/skills
            cp -r '\$DEPLOY_DIR/skills/'* $AGENTS_DIR/$agent/skills/
        fi

        # Copy yandex-stt script
        if [ -d '\$DEPLOY_DIR/scripts' ]; then
            mkdir -p $AGENTS_DIR/$agent/.scripts
            cp -r '\$DEPLOY_DIR/scripts/'* $AGENTS_DIR/$agent/.scripts/
        fi

        cat $AGENTS_DIR/$agent/config.json
    "

    echo "Config created. Starting agent..."
    start_agent "$agent" "$limit"
}

case "$cmd" in
    start)
        if [[ -z "$name" ]]; then
            echo "Error: name required"
            echo "Usage: agentctl.sh start <name> [size_mb]"
            exit 1
        fi
        start_agent "$name" "$size_mb"
        ;;
    stop)
        if [[ -z "$name" ]]; then
            echo "Error: name required"
            exit 1
        fi
        stop_agent "$name"
        ;;
    restart)
        if [[ -z "$name" ]]; then
            echo "Error: name required"
            exit 1
        fi
        restart_agent "$name"
        ;;
    status)
        if [[ -z "$name" ]]; then
            list_agents
        else
            status_agent "$name"
        fi
        ;;
    list)
        list_agents
        ;;
    delete)
        if [[ -z "$name" ]]; then
            echo "Error: name required"
            exit 1
        fi
        delete_agent "$name"
        ;;
    create)
        agent="$2"
        token="$3"
        user_chat_id="${4:-$DEFAULT_USER_CHAT_ID}"
        size_mb="${5:-$DEFAULT_SIZE_MB}"
        create_agent "$agent" "$token" "$user_chat_id" "$size_mb"
        ;;
    *)
        echo "Usage: agentctl.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  create <name> <telegram_token> [user_chat_id] [size_mb] - Create and start new agent"
        echo "  start <name> [size_mb]  - Start existing agent"
        echo "  stop <name>            - Stop agent"
        echo "  restart <name>         - Restart agent"
        echo "  status [name]          - Show status"
        echo "  list                   - List all agents"
        echo "  delete <name>          - Delete agent container"
        ;;
esac
