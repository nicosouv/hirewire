#!/bin/bash
# HireWire Scripts Management
# Main entry point for all scripts organized by category

set -e

show_help() {
    echo "🚀 HireWire Scripts Manager"
    echo "=========================="
    echo ""
    echo "Usage: $0 <category> [script] [args...]"
    echo ""
    echo "Categories:"
    echo "  data-entry    - Scripts for adding data to PostgreSQL"
    echo "  etl           - ETL pipeline scripts"
    echo "  setup         - Setup and initialization scripts"
    echo "  testing       - Testing and verification scripts"
    echo ""
    echo "Examples:"
    echo "  $0 data-entry manage          # Launch data entry manager"
    echo "  $0 etl run                    # Run complete ETL pipeline"
    echo "  $0 setup init                 # Initialize DuckDB"
    echo "  $0 testing test               # Test setup"
    echo ""
    echo "Available scripts by category:"
    echo ""
    
    echo "📊 DATA ENTRY:"
    ls -1 scripts/data_entry/*.sh | sed 's|scripts/data_entry/||' | sed 's|\.sh||' | sed 's|^|  - |'
    echo ""
    
    echo "🔄 ETL:"
    ls -1 scripts/etl/*.{sh,py} 2>/dev/null | sed 's|scripts/etl/||' | sed 's|\.(sh\|py)||' | sed 's|^|  - |'
    echo ""
    
    echo "⚙️  SETUP:"
    ls -1 scripts/setup/*.sh | sed 's|scripts/setup/||' | sed 's|\.sh||' | sed 's|^|  - |'
    echo ""
    
    echo "🧪 TESTING:"
    ls -1 scripts/testing/*.sh | sed 's|scripts/testing/||' | sed 's|\.sh||' | sed 's|^|  - |'
}

run_script() {
    local category=$1
    local script=$2
    shift 2
    
    case $category in
        "data-entry"|"data")
            case $script in
                "manage") bash scripts/data_entry/manage_data.sh "$@" ;;
                "list") bash scripts/data_entry/list_data.sh "$@" ;;
                "add-company") bash scripts/data_entry/add_company.sh "$@" ;;
                "add-job") bash scripts/data_entry/add_job_position.sh "$@" ;;
                "add-process") bash scripts/data_entry/add_process.sh "$@" ;;
                "add-interview") bash scripts/data_entry/add_interview.sh "$@" ;;
                "add-outcome") bash scripts/data_entry/add_outcome.sh "$@" ;;
                *) echo "❌ Unknown data-entry script: $script"; exit 1 ;;
            esac
            ;;
        "etl")
            case $script in
                "run") bash scripts/etl/etl_runner.sh "$@" ;;
                "update-interviews") bash scripts/etl/etl_update_past_interviews.sh "$@" ;;
                "update-status") bash scripts/etl/etl_update_process_status.sh "$@" ;;
                "sync-all") bash scripts/etl/etl_sync_all_statuses.sh "$@" ;;
                "detect-ghosted") bash scripts/etl/etl_detect_ghosted.sh "$@" ;;
                *) echo "❌ Unknown ETL script: $script"; echo "Available: run, update-interviews, update-status, sync-all, detect-ghosted"; exit 1 ;;
            esac
            ;;
        "setup")
            case $script in
                "init") bash scripts/setup/init_duckdb.sh "$@" ;;
                "superset") bash scripts/setup/init_superset.sh "$@" ;;
                *) echo "❌ Unknown setup script: $script"; echo "Available: init, superset"; exit 1 ;;
            esac
            ;;
        "testing"|"test")
            case $script in
                "test") bash scripts/testing/test_setup.sh "$@" ;;
                *) echo "❌ Unknown testing script: $script"; exit 1 ;;
            esac
            ;;
        *)
            echo "❌ Unknown category: $category"
            echo "Run '$0' without arguments to see available categories"
            exit 1
            ;;
    esac
}

# Main logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ $# -eq 1 ]; then
    echo "❌ Please specify a script name"
    echo "Run '$0 $1' to see available scripts in the $1 category"
    exit 1
fi

run_script "$@"