#!/bin/bash
# Session Handoff CLI
# Manages context handoffs between machines

set -e

DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
DB_HOST="${LONGTERM_MEMORY_HOST:-localhost}"
DB_PORT="${LONGTERM_MEMORY_PORT:-5432}"
HOSTNAME=$(hostname -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Helper function for psql
run_sql() {
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -t -A -c "$1" 2>/dev/null | grep -v "^$"
}

run_sql_quiet() {
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -t -A -c "$1" &>/dev/null
}

run_sql_pretty() {
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "$1" 2>/dev/null
}

# Usage function
usage() {
    echo -e "${BOLD}Session Handoff CLI${NC}"
    echo ""
    echo "Usage: handoff <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create <summary>    Create a new handoff"
    echo "  list, ls           List pending/picked_up handoffs"
    echo "  check              Quick view of handoffs to pick up"
    echo "  pickup <id>        Claim a handoff for this machine"
    echo "  resolve <id>       Mark handoff as resolved"
    echo "  show <id>          Show full details of a handoff"
    echo ""
    echo "Create Options:"
    echo "  --project, -p      Project name"
    echo "  --branch, -b       Git branch"
    echo "  --files, -f        Comma-separated list of modified files"
    echo "  --dir, -d          Working directory"
    echo "  --next, -n         Next step (can be used multiple times)"
    echo "  --gotcha, -g       Gotcha/warning to note"
    echo "  --blocker          Current blocker"
    echo "  --decisions        Decisions made"
    echo ""
    echo "Examples:"
    echo "  handoff create \"Added graph filtering\" -p longterm-memory -b main -n \"Test it\" -n \"Commit\""
    echo "  handoff check"
    echo "  handoff pickup 47"
    echo "  handoff resolve 47 \"Merged to main\""
}

# CREATE command
cmd_create() {
    local summary=""
    local project=""
    local branch=""
    local files=""
    local dir=""
    local next_steps=()
    local gotcha=""
    local blocker=""
    local decisions=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project|-p)
                project="$2"
                shift 2
                ;;
            --branch|-b)
                branch="$2"
                shift 2
                ;;
            --files|-f)
                files="$2"
                shift 2
                ;;
            --dir|-d)
                dir="$2"
                shift 2
                ;;
            --next|-n)
                next_steps+=("$2")
                shift 2
                ;;
            --gotcha|-g)
                gotcha="$2"
                shift 2
                ;;
            --blocker)
                blocker="$2"
                shift 2
                ;;
            --decisions)
                decisions="$2"
                shift 2
                ;;
            *)
                if [[ -z "$summary" ]]; then
                    summary="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$summary" ]]; then
        echo -e "${RED}Error: Summary is required${NC}"
        echo "Usage: handoff create \"summary\" [options]"
        exit 1
    fi

    # Auto-detect project and branch if not provided
    if [[ -z "$project" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
        project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "")
    fi
    if [[ -z "$branch" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
        branch=$(git branch --show-current 2>/dev/null || echo "")
    fi
    if [[ -z "$dir" ]]; then
        dir="$(pwd)"
    fi

    # Format next_steps as PostgreSQL array
    local next_steps_sql="NULL"
    if [[ ${#next_steps[@]} -gt 0 ]]; then
        next_steps_sql="ARRAY["
        for i in "${!next_steps[@]}"; do
            [[ $i -gt 0 ]] && next_steps_sql+=","
            next_steps_sql+="'${next_steps[$i]//\'/\'\'}'"
        done
        next_steps_sql+="]"
    fi

    # Format files as PostgreSQL array
    local files_sql="NULL"
    if [[ -n "$files" ]]; then
        files_sql="ARRAY["
        IFS=',' read -ra FILE_ARR <<< "$files"
        for i in "${!FILE_ARR[@]}"; do
            [[ $i -gt 0 ]] && files_sql+=","
            files_sql+="'${FILE_ARR[$i]//\'/\'\'}'"
        done
        files_sql+="]"
    fi

    # Insert handoff
    local sql="INSERT INTO session_handoffs (
        source_machine, summary, project, branch, files_modified,
        working_directory, next_steps, gotchas, blockers, decisions_made
    ) VALUES (
        '${HOSTNAME}',
        '${summary//\'/\'\'}',
        $([ -n "$project" ] && echo "'${project//\'/\'\'}'" || echo "NULL"),
        $([ -n "$branch" ] && echo "'${branch//\'/\'\'}'" || echo "NULL"),
        ${files_sql},
        $([ -n "$dir" ] && echo "'${dir//\'/\'\'}'" || echo "NULL"),
        ${next_steps_sql},
        $([ -n "$gotcha" ] && echo "'${gotcha//\'/\'\'}'" || echo "NULL"),
        $([ -n "$blocker" ] && echo "'${blocker//\'/\'\'}'" || echo "NULL"),
        $([ -n "$decisions" ] && echo "'${decisions//\'/\'\'}'" || echo "NULL")
    ) RETURNING id;"

    local id=$(run_sql "$sql" | head -1)

    if [[ -n "$id" && "$id" =~ ^[0-9]+$ ]]; then
        echo -e "${GREEN}✅ Handoff #${id} created${NC}"
        echo -e "${CYAN}   From: ${HOSTNAME}${NC}"
        [[ -n "$project" ]] && echo -e "${CYAN}   Project: ${project}${NC}"
        [[ -n "$branch" ]] && echo -e "${CYAN}   Branch: ${branch}${NC}"

        # Trigger sync if available
        if [[ -x "${SCRIPT_DIR}/sync_databases.sh" ]]; then
            echo -e "${YELLOW}🔄 Syncing to iCloud...${NC}"
            "${SCRIPT_DIR}/sync_databases.sh" &>/dev/null && echo -e "${GREEN}✅ Ready for pickup on another machine${NC}"
        fi
    else
        echo -e "${RED}Failed to create handoff${NC}"
        exit 1
    fi
}

# LIST command
cmd_list() {
    local show_all=false
    [[ "$1" == "--all" || "$1" == "-a" ]] && show_all=true

    local where_clause="WHERE status != 'resolved'"
    [[ "$show_all" == true ]] && where_clause=""

    echo -e "${BOLD}📋 Session Handoffs${NC}"
    echo ""

    run_sql_pretty "
        SELECT
            id as \"#\",
            status,
            source_machine as \"From\",
            COALESCE(picked_up_by, '-') as \"Picked Up By\",
            COALESCE(project, '-') as \"Project\",
            LEFT(summary, 50) || CASE WHEN LENGTH(summary) > 50 THEN '...' ELSE '' END as \"Summary\",
            to_char(created_at, 'MM-DD HH24:MI') as \"Created\"
        FROM session_handoffs
        ${where_clause}
        ORDER BY created_at DESC
        LIMIT 20;
    "
}

# CHECK command - quick view for current machine
cmd_check() {
    local count=$(run_sql "SELECT COUNT(*) FROM session_handoffs WHERE status = 'pending';")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}✅ No pending handoffs${NC}"
        return
    fi

    echo -e "${BOLD}📋 Pending Handoffs:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get pending handoffs
    while IFS='|' read -r id project branch source created summary; do
        echo -e "${CYAN}#${id}${NC} | ${project:-unspecified} (${branch:-no branch})"
        echo -e "    | From: ${source} @ ${created}"
        echo -e "    | \"${summary}\""

        # Get next steps
        local next=$(run_sql "SELECT array_to_string(next_steps, E'\n    |   ') FROM session_handoffs WHERE id = $id;")
        if [[ -n "$next" ]]; then
            echo "    |"
            echo "    | Next Steps:"
            echo "    |   ${next}"
        fi

        # Get gotchas
        local gotcha=$(run_sql "SELECT gotchas FROM session_handoffs WHERE id = $id;")
        if [[ -n "$gotcha" ]]; then
            echo "    |"
            echo -e "    | ${YELLOW}⚠️  Gotcha: ${gotcha}${NC}"
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    done < <(run_sql "
        SELECT id, project, branch, source_machine,
               to_char(created_at, 'YYYY-MM-DD HH24:MI TZ'),
               summary
        FROM session_handoffs
        WHERE status = 'pending'
        ORDER BY created_at DESC;
    ")
}

# PICKUP command
cmd_pickup() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo -e "${RED}Error: Handoff ID required${NC}"
        echo "Usage: handoff pickup <id>"
        exit 1
    fi

    # Check if handoff exists and is pending
    local status=$(run_sql "SELECT status FROM session_handoffs WHERE id = $id;")

    if [[ -z "$status" ]]; then
        echo -e "${RED}Error: Handoff #${id} not found${NC}"
        exit 1
    fi

    if [[ "$status" != "pending" ]]; then
        echo -e "${YELLOW}Warning: Handoff #${id} is already ${status}${NC}"
        exit 1
    fi

    run_sql_quiet "
        UPDATE session_handoffs
        SET status = 'picked_up',
            picked_up_at = NOW(),
            picked_up_by = '${HOSTNAME}'
        WHERE id = $id;
    "

    echo -e "${GREEN}✅ Picked up handoff #${id}${NC}"

    # Show the handoff details
    cmd_show "$id"
}

# RESOLVE command
cmd_resolve() {
    local id=$1
    local notes=$2

    if [[ -z "$id" ]]; then
        echo -e "${RED}Error: Handoff ID required${NC}"
        echo "Usage: handoff resolve <id> [\"resolution notes\"]"
        exit 1
    fi

    local notes_sql="NULL"
    [[ -n "$notes" ]] && notes_sql="'${notes//\'/\'\'}'"

    run_sql_quiet "
        UPDATE session_handoffs
        SET status = 'resolved',
            resolved_at = NOW(),
            resolution_notes = ${notes_sql}
        WHERE id = $id;
    "

    echo -e "${GREEN}✅ Handoff #${id} resolved${NC}"
    echo -e "${BLUE}📦 Archived to observations for permanent memory${NC}"

    # Trigger sync if available
    if [[ -x "${SCRIPT_DIR}/sync_databases.sh" ]]; then
        echo -e "${YELLOW}🔄 Syncing...${NC}"
        "${SCRIPT_DIR}/sync_databases.sh" &>/dev/null && echo -e "${GREEN}✅ Synced${NC}"
    fi
}

# SHOW command
cmd_show() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo -e "${RED}Error: Handoff ID required${NC}"
        echo "Usage: handoff show <id>"
        exit 1
    fi

    echo -e "${BOLD}Handoff #${id}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    run_sql_pretty "
        SELECT
            status as \"Status\",
            source_machine as \"Source Machine\",
            project as \"Project\",
            branch as \"Branch\",
            summary as \"Summary\",
            array_to_string(files_modified, ', ') as \"Files Modified\",
            working_directory as \"Working Directory\",
            array_to_string(next_steps, E'\n') as \"Next Steps\",
            gotchas as \"Gotchas\",
            blockers as \"Blockers\",
            decisions_made as \"Decisions Made\",
            to_char(created_at, 'YYYY-MM-DD HH24:MI TZ') as \"Created\",
            picked_up_by as \"Picked Up By\",
            to_char(picked_up_at, 'YYYY-MM-DD HH24:MI TZ') as \"Picked Up At\",
            resolution_notes as \"Resolution Notes\",
            to_char(resolved_at, 'YYYY-MM-DD HH24:MI TZ') as \"Resolved At\"
        FROM session_handoffs
        WHERE id = $id;
    "
}

# Main command router
case "${1:-}" in
    create)
        shift
        cmd_create "$@"
        ;;
    list|ls)
        shift
        cmd_list "$@"
        ;;
    check)
        cmd_check
        ;;
    pickup)
        shift
        cmd_pickup "$@"
        ;;
    resolve)
        shift
        cmd_resolve "$@"
        ;;
    show)
        shift
        cmd_show "$@"
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        usage
        exit 1
        ;;
esac
