# FPSync Wrapper Script

A robust Bash wrapper script for the `fpsync` utility that simplifies copying large directory trees with many files efficiently using parallel rsync processes. **Now with rsync-identical syntax behavior.**

## Overview

This script provides an enhanced interface to `fpsync`, which is part of the `fpart` package. It's designed to handle large-scale file synchronization tasks by distributing work across multiple parallel rsync processes, making it ideal for copying directories containing thousands or millions of files.

**Version 1.3** introduces:
- **Rsync-identical syntax behavior** - the trailing slash behavior now matches rsync exactly
- **Configurable rsync options** via `-O` parameter for full customization
- Enhanced error handling and validation

## Features

- **Rsync-Identical Syntax**: Trailing slash behavior matches rsync exactly
- **Configurable Rsync Options**: Full control over rsync behavior via `-O` parameter
- **Parallel Processing**: Configurable number of rsync threads for optimal performance
- **Flexible Size Limits**: Support for human-readable size units (KB, MB, GB, TB)
- **Remote Sync Support**: SSH-based remote destination copying
- **Comprehensive Validation**: Input validation for directories, sizes, and numeric parameters
- **Automatic Logging**: Organized log directory structure with timestamps
- **Error Handling**: Robust error reporting and dependency checking
- **Progress Tracking**: Verbose output with configuration summary and behavior indication

## Prerequisites

### Required Dependencies
- `fpart` and `fpsync` utilities (install the `fpart` package)
- `rsync` utility
- `bash` shell (version 4.0 or later recommended)
- `bc` calculator (for size calculations)

### For Remote Destinations
- SSH key authentication configured
- Disabled prelogin banner on remote host (for optimal performance)
- Network connectivity to remote host

### Installation
```bash
# On Ubuntu/Debian
sudo apt-get install fpart rsync bc

# On RHEL/CentOS/Fedora
sudo yum install fpart rsync bc
# or
sudo dnf install fpart rsync bc

# On macOS (using Homebrew)
brew install fpart rsync bc
```

## Usage

```bash
./fpsync-wrapper.sh [OPTIONS] <source_directory> <destination_directory>
```

### Syntax Behavior (Identical to Rsync)

The script now handles trailing slashes exactly like rsync:

| Syntax | Behavior | Result |
|--------|----------|--------|
| `source/` → `dest` | Copy contents only | Contents of `source` appear in `dest` |
| `source` → `dest` | Copy directory itself | Directory `source` created as `dest/source` |

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-T <num>` | Number of parallel rsync threads | 15 |
| `-S <size>` | Size limit per thread with units (B, KB, MB, GB, TB) | 6GB |
| `-F <num>` | Maximum files per thread | 2500 |
| `-O <options>` | Additional rsync options (quoted string) | `--archive --compress --partial` |
| `-H` | Show help message | - |

### Basic Examples

#### Copy Directory Contents (source/ syntax)
```bash
# Copy contents of dir1 into /backup/ 
./fpsync-wrapper.sh /projects/dir1/ /backup/
# Result: /backup/ contains the files from dir1
```

#### Copy Directory Itself (source syntax)
```bash
# Copy dir1 directory to /backup/dir1/
./fpsync-wrapper.sh /projects/dir1 /backup/
# Result: /backup/dir1/ contains the files from dir1
```

#### Remote Examples
```bash
# Copy directory contents to remote location
./fpsync-wrapper.sh /data/logs/ user@server:/archive/
# Result: /archive/ contains the log files

# Copy directory itself to remote location
./fpsync-wrapper.sh /data/logs user@server:/archive/
# Result: /archive/logs/ contains the log files
```

### Advanced Examples

#### Optimized for Many Small Files
```bash
./fpsync-wrapper.sh -S 100MB -T 20 -F 10000 /source/smallfiles/ /dest/
```

#### Optimized for Large Files
```bash
./fpsync-wrapper.sh -S 10GB -T 8 -F 500 /source/bigfiles /dest/
```

#### Custom Rsync Options
```bash
# Delete extra files and show detailed progress
./fpsync-wrapper.sh -O "--archive --delete --progress --verbose" /source/data/ /dest/

# Complex options with excludes (use single quotes)
./fpsync-wrapper.sh -O '-avvh --exclude ".*" --exclude "*temp*" --ignore-existing' /source/data /dest/

# High-performance options for large files
./fpsync-wrapper.sh -S 10GB -T 8 -O "--archive --sparse --compress --partial-dir=.rsync-partial" /source/bigfiles /dest/
```

#### Various Size Format Examples
```bash
# 512 megabytes with custom rsync options
./fpsync-wrapper.sh -S 512MB -O "--archive --compress --progress" /source/data/ /dest/

# 2 gigabytes with delete option
./fpsync-wrapper.sh -S 2GB -O "--archive --delete --verbose" /source/data /dest/

# 1 terabyte with size-only comparison
./fpsync-wrapper.sh -S 1TB -O "--archive --size-only" /source/data /dest/

# Case insensitive with exclude patterns
./fpsync-wrapper.sh -S 500mb -O '-av --exclude "*.tmp" --exclude "*.log"' /source/data/ /dest/
```

### Rsync Options Examples

The `-O` option allows you to pass any rsync options to customize the sync behavior:

#### Quote Handling for Complex Options
```bash
# Simple options (double quotes work fine)
./fpsync-wrapper.sh -O "--archive --delete --compress" /source /dest

# Complex options with nested quotes (use single quotes to wrap)
./fpsync-wrapper.sh -O '-avvh --exclude ".*" --exclude "*temp*" --ignore-existing' /source /dest

# Your specific complex example
./fpsync-wrapper.sh -O '-avvh --size-only --info=progress2 --exclude ".*" --exclude "*temp*" --ignore-existing --min-size=1' /source /dest

# Alternative: escape inner quotes with backslashes
./fpsync-wrapper.sh -O "-avvh --exclude \".*\" --exclude \"*temp*\"" /source /dest

# Environment variable for very complex options
export RSYNC_OPTS='-avvh --size-only --info=progress2 --exclude ".*" --exclude "*temp*" --ignore-existing --min-size=1'
./fpsync-wrapper.sh /source /dest
```

#### Common Rsync Option Combinations
```bash
# Synchronize with deletion and detailed progress
./fpsync-wrapper.sh -O "--archive --delete --progress --stats" /source/ /dest/

# Skip existing files and show transfer progress
./fpsync-wrapper.sh -O "--archive --ignore-existing --info=progress2" /source /dest

# Preserve everything including extended attributes
./fpsync-wrapper.sh -O "--archive --xattrs --acls --hard-links" /source /dest

# Bandwidth-limited transfer with compression
./fpsync-wrapper.sh -O "--archive --compress --bwlimit=10000" /source user@remote:/dest

# Checksum-based comparison (slower but more accurate)
./fpsync-wrapper.sh -O "--archive --checksum --verbose" /source /dest

# Dry run to see what would be transferred
./fpsync-wrapper.sh -O "--archive --dry-run --verbose" /source /dest
```

### Default Settings

When run with no options, the script uses:
- **Threads**: 15 parallel rsync processes
- **Files per thread**: 2500 maximum files per thread  
- **Size per thread**: 6GB maximum size per thread
- **Rsync options**: `--archive --compress --partial`

Example with defaults:
```bash
./fpsync-wrapper.sh /projects/dir1 /nfs/projects/
# Uses: 15 threads, 2500 files/thread, 6GB/thread, basic rsync options
# Result: Creates /nfs/projects/dir1/ containing the files
```

## Configuration

### Environment Variables

You can customize default behavior using environment variables:

```bash
export FPSYNC_LOGDIR="/custom/log/path"    # Default: /tmp/fpart-log
export THREADS=20                          # Default thread count
export BSIZE=8                             # Default size in GB (legacy)
export FILES=5000                          # Default files per thread
export RSYNC_OPTS="--archive --compress --delete"  # Default rsync options
```

Example usage:
```bash
# Set custom defaults
export RSYNC_OPTS="-avvh --delete --progress --exclude '*.tmp'"
export THREADS=10
./fpsync-wrapper.sh /source /dest
```

### Performance Tuning Guidelines

#### For Many Small Files
- Use smaller size limits: `-S 50MB` to `-S 200MB`
- Increase thread count: `-T 20` to `-T 50`
- Increase files per thread: `-F 5000` to `-F 20000`
- Consider using contents-only syntax (`source/`)

#### For Large Files
- Use larger size limits: `-S 2GB` to `-S 10GB`
- Moderate thread count: `-T 4` to `-T 12`
- Lower files per thread: `-F 100` to `-F 1000`

#### Network Considerations
- For remote destinations, consider network bandwidth
- Monitor system resources (CPU, memory, network)
- Adjust thread count based on available cores

## Output Example

```bash
$ ./fpsync-wrapper.sh /projects/dir1 /nfs/projects/
Starting fpsync operation...

Configuration:
  Source: /projects/dir1
  Behavior: Copy directory (rsync-like: source -> dest/source)
  Effective source: /projects/dir1
  Effective dest: /nfs/projects/dir1
  Threads: 15
  Max files per thread: 2500
  Max size per thread: 6GB
  Rsync options: --archive --compress --partial
  Log directory: /tmp/fpart-log/projects-dir1-2025-01-15_14-32-18

fpsync[12345]: starting (verbose mode)
fpsync[12345]: [fpart] preparing file list...
fpsync[12345]: [fpart] found 45023 files (125.4 GB) in 1.8 seconds
fpsync[12345]: [fpart] created 12 parts in 2.1 seconds
fpsync[12345]: starting 15 rsync workers...
...
fpsync[12345]: finished with exit code 0, transferred 125.4 GB in 456.2 seconds (281.5 MB/s)
```

## Logging

The script automatically creates organized log directories:

```
/tmp/fpart-log/
└── parentdir-sourcedir-YYYY-MM-DD_HH-MM-SS/
    ├── fpsync.log
    ├── fpart.0
    ├── fpart.1
    └── ...
```

Logs include:
- Overall fpsync operation log
- Individual thread logs
- File partition information
- Error messages and warnings
- Behavior indication (contents-only vs directory copy)

## Remote Destinations

### Supported Formats
- `user@hostname:/absolute/path`
- `user@hostname:relative/path`
- `hostname:/absolute/path`
- `hostname:relative/path`

### SSH Setup Requirements
```bash
# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096

# Copy public key to remote host
ssh-copy-id user@hostname

# Test connection
ssh user@hostname 'echo "Connection successful"'
```

### Remote Host Configuration
For optimal performance, disable prelogin banners:
```bash
# On remote host, edit /etc/ssh/sshd_config
Banner none
PrintMotd no
```

### Remote Syntax Examples
```bash
# Contents only - files appear directly in /backup/
./fpsync-wrapper.sh /local/data/ user@server:/backup/

# Directory copy - creates /backup/data/ 
./fpsync-wrapper.sh /local/data user@server:/backup/

# Absolute vs relative remote paths work the same
./fpsync-wrapper.sh /local/data user@server:backup/  # Relative
./fpsync-wrapper.sh /local/data user@server:/backup/ # Absolute
```

## Error Handling

The script includes comprehensive error checking:

- **Input Validation**: Verifies source/destination paths and parameters
- **Dependency Checking**: Ensures required utilities are installed
- **Permission Validation**: Checks read/write permissions
- **Remote Host Validation**: Basic hostname and path format checking
- **Size Validation**: Ensures minimum size requirements and valid units
- **Syntax Validation**: Clear indication of trailing slash behavior

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Check directory permissions
   ls -la /path/to/source
   ls -la /path/to/destination/parent
   ```

2. **Missing Dependencies**
   ```bash
   # Check if utilities are installed
   which fpart fpsync rsync
   ```

3. **SSH Connection Issues**
   ```bash
   # Test SSH connection
   ssh -v user@hostname
   ```

4. **Unexpected Directory Structure**
   - Check if you need trailing slash: `source/` vs `source`
   - Review the "Behavior" line in the configuration output
   - Verify effective source and destination paths shown

5. **Performance Issues**
   - Monitor system resources: `top`, `htop`, `iotop`
   - Adjust thread count based on available CPU cores
   - Consider network bandwidth for remote destinations

### Log Analysis
Check the log directory for detailed information:
```bash
# View main log
tail -f /tmp/fpart-log/latest-run/fpsync.log

# Check individual thread logs
ls /tmp/fpart-log/latest-run/
```

## Behavior Comparison Table

| Command | Rsync Equivalent | Result |
|---------|-----------------|--------|
| `./script /src/dir /dest` | `rsync -av /src/dir /dest/` | `/dest/dir/` created |
| `./script /src/dir/ /dest` | `rsync -av /src/dir/ /dest/` | Contents in `/dest/` |
| `./script /src/dir user@host:/dest` | `rsync -av /src/dir user@host:/dest/` | `user@host:/dest/dir/` |
| `./script /src/dir/ user@host:/dest` | `rsync -av /src/dir/ user@host:/dest/` | Contents in `user@host:/dest/` |

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes with appropriate tests
4. Ensure all error handling paths are covered
5. Update documentation as needed
6. Submit a pull request

### Code Style
- Follow existing bash scripting conventions
- Use `set -euo pipefail` for error handling
- Include comprehensive input validation
- Add descriptive comments for complex logic
- Use readonly variables where appropriate

## License

This script is provided under the GNU General Public License v3.0. See LICENSE file for details.

## References

- [FPart Project](http://www.fpart.org/#fpsync)
- [FPart GitHub Repository](https://github.com/martymac/fpart)
- [Rsync Manual](https://rsync.samba.org/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/bash.html)

## Version History

- **v1.3**: Added rsync-identical syntax behavior with trailing slash support and configurable rsync options via `-O`
- **v1.2**: Enhanced size parsing and validation with human-readable units
- **v1.1**: Added remote destination support
- **v1.0**: Initial release with basic functionality
