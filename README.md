# fpsync-wrapper

A robust bash wrapper script for the `fpsync` utility that simplifies parallel file synchronization for large directory trees with many files.

## Overview

This script provides a user-friendly interface to `fpsync` (part of the `fpart` package), which uses multiple parallel `rsync` processes to efficiently copy large datasets. It's particularly effective for directories containing thousands of files or multi-terabyte datasets.

## Features

- ✅ **Parallel Processing**: Configurable number of concurrent rsync threads
- ✅ **Local & Remote Support**: Copy to local directories or remote hosts via SSH
- ✅ **Input Validation**: Comprehensive validation of directories and parameters
- ✅ **Dependency Checking**: Automatically verifies required tools are available
- ✅ **Organized Logging**: Timestamped log directories for tracking operations
- ✅ **Flexible Configuration**: Customizable file limits, size limits, and thread counts
- ✅ **Error Handling**: Fails fast with clear error messages

## Prerequisites

### Required Software
- `fpart` package (includes `fpsync` utility)
- `rsync`
- `bash` 4.0+

### Installation

#### On RHEL/CentOS/Rocky Linux
```bash
# Install from EPEL or download directly
sudo dnf install fpart rsync

# Or download specific version
wget https://kojipkgs.fedoraproject.org/packages/fpart/1.5.1/1.el9/x86_64/fpart-1.5.1-1.el9.x86_64.rpm
sudo rpm -ivh fpart-1.5.1-1.el9.x86_64.rpm
```

#### On Ubuntu/Debian
```bash
sudo apt update
sudo apt install fpart rsync
```

#### From Source
```bash
git clone https://github.com/martymac/fpart.git
cd fpart
./configure && make && sudo make install
```

### For SSH Destinations
- SSH key-based authentication configured
- Prelogin banner disabled on remote host (recommended for performance)
- Remote host must have `rsync` available

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd fpsync-wrapper
```

2. Make the script executable:
```bash
chmod +x fpsync-wrapper.sh
```

3. Optionally, add to your PATH:
```bash
sudo cp fpsync-wrapper.sh /usr/local/bin/fpsync-wrapper
```

## Usage

### Basic Syntax
```bash
./fpsync-wrapper.sh [OPTIONS] <source_directory> <destination_directory>
```

### Options
- `-T <num>`: Number of parallel rsync threads (default: 15)
- `-S <num>`: Size limit per thread in GB (default: 6)  
- `-F <num>`: Maximum files per thread (default: 2500)
- `-H`: Show help message

### Examples

#### Local Copy
```bash
# Basic copy with defaults
./fpsync-wrapper.sh /data/experiment1 /backup/experiment1

# High-performance copy for many small files
./fpsync-wrapper.sh -T 25 -S 4 -F 1000 /data/smallfiles /backup/smallfiles

# Copy optimized for large files
./fpsync-wrapper.sh -T 8 -S 20 -F 100 /data/bigfiles /backup/bigfiles
```

#### Remote Copy via SSH
```bash
# Copy to remote server
./fpsync-wrapper.sh /data/experiment1 user@backupserver:/backup/experiment1

# Copy with custom configuration
./fpsync-wrapper.sh -T 10 -S 8 -F 2000 /data/project user@server.example.com:/remote/backup/project
```

## Configuration

### Environment Variables
- `FPSYNC_LOGDIR`: Custom log directory (default: `/tmp/fpart-log`)
- `THREADS`: Default thread count
- `BSIZE`: Default size limit in GB  
- `FILES`: Default file limit per thread

### Performance Tuning

| Scenario | Recommended Settings | Reasoning |
|----------|---------------------|-----------|
| Many small files | `-T 20-30 -S 2-4 -F 1000-2000` | More threads, smaller chunks |
| Large files | `-T 5-10 -S 10-20 -F 50-200` | Fewer threads, larger chunks |
| Mixed workload | `-T 15 -S 6 -F 2500` (defaults) | Balanced approach |
| Network limited | `-T 5-8 -S 8-12` | Reduce threads to avoid congestion |

## Log Files

Logs are automatically organized in timestamped directories:
```
/tmp/fpart-log/
└── parent-source-2024-01-15_14-30-25/
    ├── fpsync.log
    ├── fp.0.log
    ├── fp.1.log
    └── ...
```

Each run creates a unique log directory named: `<parent>-<source>-<timestamp>`

## Performance Considerations

### Best Performance Scenarios
- Source and destination are locally mounted or on high-speed NFS
- Sufficient RAM for file system caching
- Fast storage (SSD preferred)
- High-bandwidth, low-latency network for remote copies

### SSH Optimization
For remote copies via SSH:
1. Use SSH key authentication (no passwords)
2. Disable prelogin banner: `Banner none` in `/etc/ssh/sshd_config`
3. Consider SSH connection multiplexing for many small transfers
4. Ensure remote host has adequate resources

## Troubleshooting

### Common Issues

**"Missing required dependencies"**
- Install `fpart` package and ensure `rsync` is available
- Verify tools are in your PATH: `which fpart fpsync rsync`

**"Source directory does not exist"**
- Check the source path is correct and accessible
- Ensure you have read permissions on the source directory

**"Destination parent directory does not exist"**
- Create the parent directory: `mkdir -p /path/to/parent`
- For remote destinations, ensure the path exists on the remote host

**SSH connection issues**
- Test SSH connectivity: `ssh user@hostname`
- Verify SSH key authentication is working
- Check remote host has sufficient disk space

**Poor performance**
- Adjust thread count based on your storage and network capacity
- Monitor system resources during transfer
- Consider the file size distribution in your dataset

### Debug Mode
For detailed debugging, you can modify the script to add `set -x` or run fpsync manually:
```bash
fpsync -v -n 15 -f 2500 -s $((6*1024*1024*1024)) -d /tmp/debug-logs /source /dest
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit with descriptive messages
5. Submit a pull request

### Testing
Before submitting changes:
- Test with both local and remote destinations
- Test error conditions (missing directories, invalid parameters)
- Verify on different Linux distributions
- Test with various file size distributions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [fpart/fpsync Official Documentation](http://www.fpart.org/#fpsync)
- [fpart GitHub Repository](https://github.com/martymac/fpart)
- [rsync Manual](https://rsync.samba.org/documentation.html)

## Changelog

### v1.1.0
- Added SSH destination support (`user@hostname:/path`)
- Improved input validation and error handling
- Added comprehensive dependency checking
- Reorganized code structure with better functions
- Enhanced documentation and help text

### v1.0.0
- Initial release with basic fpsync wrapper functionality
- Local directory copying support
- Configurable threading and file limits
