#!/bin/bash

#set -euo pipefail

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  push                     Push current changes to the remote GitHub repository.
  secrets [--file=FILE]    Set GitHub secrets and variables using the specified .env file (default: .env).
  yeet init [--file=FILE]  Create or append a template to the .env file.
  help                     Show this help message.

Options:
  --file=FILE              Path to the .env file to use (default: .env)
EOF
}

template_content='
# ─── GitHub Token ─────────────────────────────────────
GITHUB_TOKEN=

# ─── Secrets (sent as GitHub Secrets) ─────────────────
# API_KEY=your_api_key_here
# DATABASE_URL=your_db_url_here
# SENTRY_DSN=your_sentry_dsn_here

# ─── Variables Block (sent as GitHub Actions Variables) ──
# Variables
# ENVIRONMENT=production
# LOG_LEVEL=debug
# FEATURE_FLAG=true
# End Variables
'
push_to_remote() {
    echo "Pushing to the remote repository..."
    if git push; then
        echo "✅ Push successful!"
    else
        echo "❌ Failed to push to the remote repository."
        exit 1
    fi
}

set_secrets() {
    local ENV_FILE="$1"
    echo "🔐 Setting secrets from $ENV_FILE..."
    local success_count=0 fail_count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^GITHUB_TOKEN= || "$line" =~ ^#\ Variables ]] && continue
        var_name=$(echo "$line" | cut -d '=' -f 1)
        var_value=$(echo "$line" | cut -d '=' -f 2-)

        if echo "$var_value" | gh secret set "$var_name" --repo "$REPO" --app actions > /dev/null 2>&1; then
            echo "✅ Secret set: $var_name"
            ((success_count++))
        else
            echo "❌ Failed: $var_name"
            ((fail_count++))
        fi
    done < "$ENV_FILE"

    echo "---------------------------------"
    echo "$success_count secrets set successfully."
    echo "$fail_count secrets failed to set."
}

set_variables() {
    local ENV_FILE="$1"
    echo "📦 Setting variables from $ENV_FILE..."
    local success_count=0 fail_count=0 in_variables_section=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#\ Variables ]] && { in_variables_section=1; continue; }
        [[ "$line" =~ ^#\ End\ Variables ]] && { in_variables_section=0; continue; }
        [[ $in_variables_section -eq 0 || -z "$line" || "$line" =~ ^# ]] && continue

        var_name=$(echo "$line" | cut -d '=' -f 1 | xargs)
        var_value=$(echo "$line" | cut -d '=' -f 2- | xargs)

        if [[ -z "$var_name" || -z "$var_value" ]]; then
            echo "⚠️  Skipping malformed line: $line"
            continue
        fi

        if echo "$var_value" | gh variable set "$var_name" --repo "$REPO" > /dev/null 2>&1; then
            echo "✅ Variable set: $var_name"
            ((success_count++))
        else
            echo "❌ Failed: $var_name"
            ((fail_count++))
        fi
    done < "$ENV_FILE"

    echo "---------------------------------"
    echo "$success_count variables set successfully."
    echo "$fail_count variables failed to set."
}

set_github_secrets() {
    local ENV_FILE=".env"
    for arg in "$@"; do
        [[ "$arg" =~ ^--file= ]] && ENV_FILE="${arg#--file=}"
    done

    GITHUB_TOKEN=$(grep '^GITHUB_TOKEN=' "$ENV_FILE" | cut -d '=' -f 2-)
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "❌ GITHUB_TOKEN not found in $ENV_FILE"
        exit 1
    fi

    REPO_URL=$(git config --get remote.origin.url)
    REPO=$(echo "$REPO_URL" | sed -n 's#.*github\.com[:/]\([^/]*\)/\([^\.]*\).*#\1/\2#p')

    echo "🔧 Setting secrets/variables for: $REPO"
    set_secrets "$ENV_FILE"
    set_variables "$ENV_FILE"
}

yeet_init() {
    local ENV_FILE=".env"
    for arg in "$@"; do
        [[ "$arg" =~ ^--file= ]] && ENV_FILE="${arg#--file=}"
    done

    echo "🌀 Initializing $ENV_FILE..."
    touch "$ENV_FILE"
    echo "$template_content" >> "$ENV_FILE"
    echo "✅ Appended template to $ENV_FILE"
}

COMMAND="${1:-help}"

case "$COMMAND" in
    push)
        push_to_remote
        ;;
    secrets)
        shift
        set_github_secrets "$@"
        ;;
    yeet)
        SUBCOMMAND="${2:-}"
        if [[ "$SUBCOMMAND" == "init" ]]; then
            shift 2
            yeet_init "$@"
        else
            echo "❌ Unknown yeet subcommand: $SUBCOMMAND"
            show_help
            exit 1
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
