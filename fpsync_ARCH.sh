#!/bin/bash

# Improved fpsync wrapper script with rsync-like syntax and better error handling

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.3"

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

# Enhanced size parsing function
parse_size() {
    local size_input="$1"
    local size_bytes
    
    # Remove any whitespace
    size_input="${size_input// /}"
    
    # Convert to uppercase for case-insensitive matching
    local size_upper="${size_input^^}"
    
    # Extract numeric part and unit
    if [[ "$size_upper" =~ ^([0-9]+)([KMGT]?B?)$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        # Default to bytes if no unit specified
        if [[ -z "$unit" ]]; then
            unit="B"
        fi
        
        # Convert to bytes based on unit
        case "$unit" in
            "B")
                size_bytes="$number"
                ;;
            "K"|"KB")
                size_bytes=$((number * 1024))
                ;;
            "M"|"MB")
                size_bytes=$((number * 1024 * 1024))
                ;;
            "G"|"GB")
                size_bytes=$((number * 1024 * 1024 * 1024))
                ;;
            "T"|"TB")
                size_bytes=$((number * 1024 * 1024 * 1024 * 1024))
                ;;
            *)
                error_exit "Invalid size unit: $unit. Supported units: B, KB, MB, GB, TB"
                ;;
        esac
        
        echo "$size_bytes"
    else
        error_exit "Invalid size format: '$size_input'. Expected format: number[unit] (e.g., 500MB, 2GB, 1024KB)"
    fi
}

# Function to format bytes into human-readable format
format_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local size="$bytes"
    local unit_index=0
    
    while ((size >= 1024 && unit_index < 4)); do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    echo "${size}${units[unit_index]}"
}

# Updated validation for size parameter
validate_size() {
    local size_input="$1"
    local parsed_size
    
    parsed_size=$(parse_size "$size_input") || return 1
    
    # Ensure minimum size (1KB)
    if ((parsed_size < 1024)); then
        error_exit "Size must be at least 1KB, got: $(format_size "$parsed_size")"
    fi
    
    echo "$parsed_size"
}

# Function to normalize source path for rsync-like behavior
normalize_source_path() {
    local src="$1"
    
    # Remove trailing slashes to ensure consistent behavior
    src="${src%/}"
    
    echo "$src"
}

# Function to construct destination path for rsync-like behavior
construct_dest_path() {
    local src="$1"
    local dest="$2"
    local use_contents_only="$3"
    
    # Check if destination is remote
    if [[ "$dest" =~ : ]]; then
        # Remote destination
        local remote_part="${dest%%:*}"
        local remote_path="${dest#*:}"
        
        if [[ "$use_contents_only" == "true" ]]; then
            # Copy contents only - use destination as-is
            echo "$dest"
        else
            # Copy directory - append source directory name
            local src_basename
            src_basename="$(basename "$src")"
            
            # Handle trailing slash in remote path
            if [[ "$remote_path" == */ ]] || [[ "$remote_path" == "" ]]; then
                echo "${remote_part}:${remote_path}${src_basename}"
            else
                echo "${remote_part}:${remote_path}/${src_basename}"
            fi
        fi
    else
        # Local destination
        if [[ "$use_contents_only" == "true" ]]; then
            # Copy contents only - use destination as-is
            echo "$dest"
        else
            # Copy directory - append source directory name
            local src_basename
            src_basename="$(basename "$src")"
            echo "$dest/$src_basename"
        fi
    fi
}

# Improved validation function for directories
validate_directory() {
    local dir="$1"
    local type="$2"
    
    [[ -n "$dir" ]] || error_exit "$type directory not specified"
    
    if [[ "$type" == "Source" ]]; then
        [[ -d "$dir" ]] || error_exit "$type directory '$dir' does not exist"
        [[ -r "$dir" ]] || error_exit "$type directory '$dir' is not readable"
    elif [[ "$type" == "Destination" ]]; then
        # Check if destination is remote (rsync format)
        # Supported formats: user@host:/path, user@host:path, host:/path, host:path
        if [[ "$dir" =~ : ]]; then
            # Remote destination - extract hostname and path for basic validation
            local remote_part="${dir%%:*}"
            local remote_path="${dir#*:}"
            
            # Validate hostname/user@hostname format
            if [[ "$remote_part" =~ @ ]]; then
                # Format: user@hostname
                local username="${remote_part%%@*}"
                local hostname="${remote_part##*@}"
                
                # Basic validation for username and hostname
                [[ -n "$username" ]] || error_exit "Empty username in remote destination: $dir"
                [[ -n "$hostname" ]] || error_exit "Empty hostname in remote destination: $dir"
                [[ "$hostname" =~ ^[a-zA-Z0-9._-]+$ ]] || \
                    error_exit "Invalid hostname format: $hostname"
            else
                # Format: hostname (no user specified)
                [[ "$remote_part" =~ ^[a-zA-Z0-9._-]+$ ]] || \
                    error_exit "Invalid hostname format: $remote_part"
            fi
            
            # Remote path validation - allow both absolute and relative paths
            # rsync supports both /absolute/path and relative/path
            [[ -n "$remote_path" ]] || error_exit "Empty path in remote destination: $dir"
            
            echo "Note: Remote destination detected: $dir"
            echo "      Ensure SSH key authentication is configured and the remote path is accessible."
        else
            # Local destination - validate parent directory exists and is writable
            local dest_parent
            if [[ -d "$dir" ]]; then
                # Destination exists - check if it's writable
                [[ -w "$dir" ]] || error_exit "Destination directory '$dir' is not writable"
            else
                # Destination doesn't exist - check parent directory
                dest_parent="$(dirname "$dir")"
                [[ -d "$dest_parent" ]] || error_exit "Destination parent directory '$dest_parent' does not exist"
                [[ -w "$dest_parent" ]] || error_exit "Destination parent directory '$dest_parent' is not writable"
            fi
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
    local src_dir_orig="$1"
    local dest_dir_orig="$2"
    
    echo "Starting fpsync operation..."
    
    # Normalize source path (remove trailing slashes)
    local src_dir
    src_dir=$(normalize_source_path "$src_dir_orig")
    
    # Determine if we should copy contents only (rsync-like behavior)
    local use_contents_only="false"
    if [[ "$src_dir_orig" == */ ]]; then
        use_contents_only="true"
    fi
    
    # Construct destination path based on rsync-like behavior
    local dest_dir
    dest_dir=$(construct_dest_path "$src_dir" "$dest_dir_orig" "$use_contents_only")
    
    # Validate inputs
    validate_directory "$src_dir" "Source"
    validate_directory "$dest_dir_orig" "Destination"
    validate_numeric "$THREADS" "THREADS" 1
    validate_numeric "$FILES" "FILES" 1
    
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
    echo "  Source: $src_dir_orig"
    if [[ "$use_contents_only" == "true" ]]; then
        echo "  Behavior: Copy contents only (rsync-like: source/ -> dest)"
        echo "  Effective source: $src_dir"
        echo "  Effective dest: $dest_dir_orig"
    else
        echo "  Behavior: Copy directory (rsync-like: source -> dest/source)"
        echo "  Effective source: $src_dir"
        echo "  Effective dest: $dest_dir"
    fi
    echo "  Threads: $THREADS"
    echo "  Max files per thread: $FILES"
    echo "  Max size per thread: $(format_size "$SIZE")"
    echo "  Log directory: $runlog"
    echo
    
    # Execute fpsync with the appropriate paths
    if [[ "$use_contents_only" == "true" ]]; then
        # Copy contents: add trailing slash to source for fpsync
        fpsync -v -n "$THREADS" -f "$FILES" -s "$SIZE" -d "$runlog" "$src_dir/" "$dest_dir_orig"
    else
        # Copy directory: use constructed destination path
        fpsync -v -n "$THREADS" -f "$FILES" -s "$SIZE" -d "$runlog" "$src_dir" "$dest_dir"
    fi
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Wrapper script for fpsync utility with rsync-like syntax

DESCRIPTION:
    This script provides a simplified interface to fpsync for copying large
    directory trees with many files efficiently using parallel rsync processes.
    The syntax now matches rsync behavior exactly.

SYNTAX BEHAVIOR (identical to rsync):
    source/     -> dest       # Copy contents of source into dest
    source      -> dest       # Copy source directory as dest/source

PREREQUISITES:
    - fpart and fpsync utilities must be installed and in PATH
    - rsync must be available
    - For remote destinations: SSH key authentication and disabled prelogin banner
    - Best performance with locally mounted or NFS-mounted directories

USAGE:
    $SCRIPT_NAME [OPTIONS] <source_directory> <destination_directory>

OPTIONS:
    -T <num>      Number of parallel rsync threads (default: $THREADS)
    -S <size>     Size limit per thread with units (default: ${BSIZE}GB)
                  Supported units: B, KB, MB, GB, TB (case insensitive)
                  Examples: 500MB, 2GB, 1024KB, 1TB
    -F <num>      Maximum files per thread (default: $FILES)
    -H            Show this help message

EXAMPLES:
    # Copy directory contents (like rsync /source/ /dest/)
    $SCRIPT_NAME /source/mydir/ /dest/
    # Result: /dest/ contains the contents of mydir

    # Copy directory itself (like rsync /source/mydir /dest/)
    $SCRIPT_NAME /source/mydir /dest/
    # Result: /dest/mydir/ contains the contents of mydir

    # Remote copy with contents only
    $SCRIPT_NAME /source/data/ user@server:/backup/
    # Result: /backup/ contains the contents of data

    # Remote copy with directory
    $SCRIPT_NAME /source/data user@server:/backup/
    # Result: /backup/data/ contains the contents of data

    # Optimized for large files
    $SCRIPT_NAME -S 10GB -T 8 /source/bigfiles/ /dest/
    
    # Optimized for many small files  
    $SCRIPT_NAME -S 100MB -T 20 -F 10000 /source/smallfiles /dest/

SIZE EXAMPLES:
    -S 512MB      512 megabytes
    -S 2GB        2 gigabytes  
    -S 1024KB     1024 kilobytes (1MB)
    -S 1TB        1 terabyte
    -S 500mb      500 megabytes (case insensitive)

ENVIRONMENT VARIABLES:
    FPSYNC_LOGDIR    Custom log directory (default: /tmp/fpart-log)
    THREADS          Default thread count
    BSIZE            Default size limit in GB (legacy, use -S option instead)
    FILES            Default file limit per thread

NOTES:
    - Trailing slash behavior matches rsync exactly:
      * source/  -> copies contents only
      * source   -> copies directory itself
    - For many small files: use smaller size limit (-S 100MB), increase threads (-T)
    - For large files: use larger size limit (-S 5GB), optimize thread count (-T)
    - Log files are automatically organized by source directory name and timestamp
    - Remote destinations: Use format user@hostname:/path or hostname:/path with SSH key authentication
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
                # Parse size with units
                SIZE=$(validate_size "$OPTARG")
                # Calculate BSIZE for display purposes (convert back to GB equivalent)
                BSIZE=$(echo "scale=2; $SIZE / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "$((SIZE / 1024 / 1024 / 1024))")
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
    
    # Convert source to absolute path (only for local paths and only if it doesn't have trailing slash)
    if [[ -d "${src_dir%/}" ]] && [[ "$src_dir" != */ ]]; then
        src_dir="$(cd "${src_dir%/}" && pwd)"
    fi
    
    # Execute main function
    fpsync_it "$src_dir" "$dest_dir"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
