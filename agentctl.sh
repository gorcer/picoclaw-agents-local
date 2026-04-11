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

HOST="${SSH_HOST:-srv}"
AGENTS_DIR="$HOME/picoclaw-agents"

# Default disk limit in MB
DEFAULT_SIZE_MB=100

cmd="$1"
name="$2"
size_mb="${3:-$DEFAULT_SIZE_MB}"

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
        docker run -d \
            --name picoclaw-$agent \
            --restart unless-stopped \
            --storage-opt size=${limit}M \
            --add-host=host.docker.internal:host-gateway \
            -v $AGENTS_DIR/$agent/agent_config.json:/app/agent_config.json:ro \
            -e PICOCLAW_CONFIG=/app/agent_config.json \
            -e HTTPS_PROXY=http://host.docker.internal:10808 \
            -e HTTP_PROXY=http://host.docker.internal:10808 \
            -e no_proxy='*' \
            picoclaw:1.0

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
    local api_key="$3"
    local limit="${4:-$DEFAULT_SIZE_MB}"

    if [[ -z "$agent" || -z "$token" || -z "$api_key" ]]; then
        echo "Error: name, telegram_token, and llm_api_key required"
        echo "Usage: agentctl.sh create <name> <telegram_token> <llm_api_key> [size_mb]"
        exit 1
    fi

    echo "Creating agent '$agent' with ${limit}MB disk limit..."

    # Create config on srv
    sshsrv "
        mkdir -p $AGENTS_DIR/$agent

        cat > $AGENTS_DIR/$agent/agent_config.json << 'EOF'
{
  \"telegram_token\": \"$token\",
  \"llm_api_key\": \"$api_key\",
  \"proxy\": \"http://host.docker.internal:10808\"
}
EOF

        chmod 600 $AGENTS_DIR/$agent/agent_config.json
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
        if [[ -z "$name" ]]; then
            echo "Error: name, telegram_token, and llm_api_key required"
            echo "Usage: agentctl.sh create <name> <telegram_token> <llm_api_key> [size_mb]"
            exit 1
        fi
        token="$3"
        api_key="$4"
        size_mb="${5:-$DEFAULT_SIZE_MB}"
        create_agent "$name" "$token" "$api_key" "$size_mb"
        ;;
    *)
        echo "Usage: agentctl.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  create <name> <token> <api_key> [size_mb] - Create and start new agent"
        echo "  start <name> [size_mb]  - Start existing agent"
        echo "  stop <name>            - Stop agent"
        echo "  restart <name>         - Restart agent"
        echo "  status [name]          - Show status"
        echo "  list                   - List all agents"
        echo "  delete <name>          - Delete agent container"
        ;;
esac
