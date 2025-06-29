#!/bin/bash

# Improved fpsync wrapper script with better error handling and validation

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.1"

# Configuration
MAILTO=""
export PATH="$SCRIPT_DIR:$PATH"
readonly LOGDIR="${FPSYNC_LOGDIR:-/tmp/fpart-log}"

# Default values
THREADS="${THREADS:-15}"
BSIZE="${BSIZE:-6}"
FILES="${FILES:-2500}"

# Derived values
SIZE="${SIZE:-$((BSIZE * 1024 * 1024 * 1024))}"

# Error reporting function
error_exit() {
    echo "ERROR: $*" >&2
    exit 1
}

# Validation functions
validate_directory() {
    local dir="$1"
    local type="$2"
    
    [[ -n "$dir" ]] || error_exit "$type directory not specified"
    
    if [[ "$type" == "Source" ]]; then
        [[ -d "$dir" ]] || error_exit "$type directory '$dir' does not exist"
        [[ -r "$dir" ]] || error_exit "$type directory '$dir' is not readable"
    elif [[ "$type" == "Destination" ]]; then
        # Check if destination is remote (contains hostname@)
        if [[ "$dir" =~ ^[^@]+@[^:]+:.* ]]; then
            # Remote destination - extract hostname and path for basic validation
            local remote_host="${dir%%:*}"
            local remote_path="${dir#*:}"
            
            # Validate hostname format (basic check)
            [[ "$remote_host" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]] || \
                error_exit "Invalid remote destination format. Expected: user@hostname:/path"
            
            # Validate path is absolute
            [[ "$remote_path" =~ ^/ ]] || \
                error_exit "Remote destination path must be absolute: $remote_path"
            
            echo "Note: Remote destination detected. Ensure SSH key authentication is configured."
        else
            # Local destination - validate as before
            local dest_parent
            dest_parent="$(dirname "$dir")"
            [[ -d "$dest_parent" ]] || error_exit "Destination parent directory '$dest_parent' does not exist"
            [[ -w "$dest_parent" ]] || error_exit "Destination parent directory '$dest_parent' is not writable"
        fi
    fi
}

validate_numeric() {
    local value="$1"
    local name="$2"
    local min="${3:-1}"
    
    [[ "$value" =~ ^[0-9]+$ ]] || error_exit "$name must be a positive integer, got: '$value'"
    ((value >= min)) || error_exit "$name must be >= $min, got: $value"
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in fpart fpsync rsync; do
        command -v "$cmd" >/dev/null 2>&1 || missing_deps+=("$cmd")
    done
    
    if ((${#missing_deps[@]} > 0)); then
        error_exit "Missing required dependencies: ${missing_deps[*]}. Please install fpart package and ensure rsync is available"
    fi
}

create_log_directory() {
    local runlog="$1"
    
    mkdir -p "$runlog" || error_exit "Failed to create log directory: $runlog"
    [[ -w "$runlog" ]] || error_exit "Log directory is not writable: $runlog"
}

fpsync_it() {
    local src_dir="$1"
    local dest_dir="$2"
    
    echo "Starting fpsync operation..."
    
    # Validate inputs
    validate_directory "$src_dir" "Source"
    validate_directory "$dest_dir" "Destination"
    validate_numeric "$THREADS" "THREADS" 1
    validate_numeric "$FILES" "FILES" 1
    validate_numeric "$BSIZE" "BSIZE" 1
    
    # Check dependencies
    check_dependencies
    
    # Create log directory structure
    local starttime
    starttime="$(date '+%Y-%m-%d_%H-%M-%S')"
    
    local d2
    d2="$(dirname "$src_dir")"
    local runlog="${LOGDIR}/$(basename "$d2")-$(basename "$src_dir")-${starttime}"
    
    create_log_directory "$runlog"
    
    echo "Configuration:"
    echo "  Source: $src_dir"
    echo "  Destination: $dest_dir"
    echo "  Threads: $THREADS"
    echo "  Max files per thread: $FILES"
    echo "  Max size per thread: ${BSIZE}GB"
    echo "  Log directory: $runlog"
    echo
    
    # Execute fpsync
    fpsync -v -n "$THREADS" -f "$FILES" -s "$SIZE" -d "$runlog" "$src_dir" "$dest_dir"
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Wrapper script for fpsync utility

DESCRIPTION:
    This script provides a simplified interface to fpsync for copying large
    directory trees with many files efficiently using parallel rsync processes.

PREREQUISITES:
    - fpart and fpsync utilities must be installed and in PATH
    - rsync must be available
    - For remote destinations: SSH key authentication and disabled prelogin banner
    - Best performance with locally mounted or NFS-mounted directories

USAGE:
    $SCRIPT_NAME [OPTIONS] <source_directory> <destination_directory>

OPTIONS:
    -T <num>    Number of parallel rsync threads (default: $THREADS)
    -S <num>    Size limit per thread in GB (default: $BSIZE)
    -F <num>    Maximum files per thread (default: $FILES)
    -H          Show this help message

EXAMPLES:
    # Basic local copy
    $SCRIPT_NAME /source/path /dest/path

    # Remote copy via SSH
    $SCRIPT_NAME /source/path user@remotehost:/dest/path

    # Custom configuration with remote destination
    $SCRIPT_NAME -T 25 -S 10 -F 5000 /source/path user@server:/dest/path

ENVIRONMENT VARIABLES:
    FPSYNC_LOGDIR    Custom log directory (default: /tmp/fpart-log)
    THREADS          Default thread count
    BSIZE            Default size limit in GB
    FILES            Default file limit per thread

NOTES:
    - For many small files: reduce size (-S), increase threads (-T)
    - For large files: increase size (-S), optimize thread count (-T)
    - Log files are automatically organized by source directory name and timestamp
    - Remote destinations: Use format user@hostname:/path with SSH key authentication
    - For SSH copies: Disable prelogin banner on remote host for best performance

MORE INFO:
    http://www.fpart.org/#fpsync
    https://github.com/martymac/fpart

EOF
}

# Main execution
main() {
    local src_dir=""
    local dest_dir=""
    
    # Parse command line arguments
    while getopts 'HT:F:S:' option; do
        case "$option" in
            T)
                THREADS="$OPTARG"
                ;;
            F)
                FILES="$OPTARG"
                ;;
            S)
                BSIZE="$OPTARG"
                SIZE=$((BSIZE * 1024 * 1024 * 1024))
                ;;
            H)
                show_help
                exit 0
                ;;
            *)
                error_exit "Invalid option. Use -H for help."
                ;;
        esac
    done
    
    # Get positional arguments
    shift $((OPTIND - 1))
    
    (( $# == 2 )) || error_exit "Expected exactly 2 arguments (source and destination directories). Use -H for help."
    
    src_dir="$1"
    dest_dir="$2"
    
    # Convert source to absolute path (only for local paths)
    if [[ -d "$src_dir" ]]; then
        src_dir="$(cd "$src_dir" && pwd)"
    fi
    
    # Execute main function
    fpsync_it "$src_dir" "$dest_dir"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
