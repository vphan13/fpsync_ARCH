# FPSync Wrapper Script

A robust Bash wrapper script for the `fpsync` utility that simplifies copying large directory trees with many files efficiently using parallel rsync processes.

## Overview

This script provides an enhanced interface to `fpsync`, which is part of the `fpart` package. It's designed to handle large-scale file synchronization tasks by distributing work across multiple parallel rsync processes, making it ideal for copying directories containing thousands or millions of files.

## Features

- **Parallel Processing**: Configurable number of rsync threads for optimal performance
- **Flexible Size Limits**: Support for human-readable size units (KB, MB, GB, TB)
- **Remote Sync Support**: SSH-based remote destination copying
- **Comprehensive Validation**: Input validation for directories, sizes, and numeric parameters
- **Automatic Logging**: Organized log directory structure with timestamps
- **Error Handling**: Robust error reporting and dependency checking
- **Progress Tracking**: Verbose output with configuration summary

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

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-T <num>` | Number of parallel rsync threads | 15 |
| `-S <size>` | Size limit per thread with units (B, KB, MB, GB, TB) | 6GB |
| `-F <num>` | Maximum files per thread | 2500 |
| `-H` | Show help message | - |

### Examples

#### Basic Local Copy
```bash
./fpsync-wrapper.sh /source/data /backup/data
```

#### Remote Copy via SSH
```bash
./fpsync-wrapper.sh /local/data user@server.example.com:/remote/backup
```

#### Optimized for Many Small Files
```bash
./fpsync-wrapper.sh -S 100MB -T 20 -F 10000 /source/smallfiles /dest/smallfiles
```

#### Optimized for Large Files
```bash
./fpsync-wrapper.sh -S 10GB -T 8 -F 500 /source/bigfiles /dest/bigfiles
```

#### Various Size Format Examples
```bash
# 512 megabytes
./fpsync-wrapper.sh -S 512MB /source /dest

# 2 gigabytes
./fpsync-wrapper.sh -S 2GB /source /dest

# 1 terabyte
./fpsync-wrapper.sh -S 1TB /source /dest

# Case insensitive
./fpsync-wrapper.sh -S 500mb /source /dest
```

## Configuration

### Environment Variables

You can customize default behavior using environment variables:

```bash
export FPSYNC_LOGDIR="/custom/log/path"    # Default: /tmp/fpart-log
export THREADS=20                          # Default thread count
export BSIZE=8                            # Default size in GB (legacy)
export FILES=5000                         # Default files per thread
```

### Performance Tuning Guidelines

#### For Many Small Files
- Use smaller size limits: `-S 50MB` to `-S 200MB`
- Increase thread count: `-T 20` to `-T 50`
- Increase files per thread: `-F 5000` to `-F 20000`

#### For Large Files
- Use larger size limits: `-S 2GB` to `-S 10GB`
- Moderate thread count: `-T 4` to `-T 12`
- Lower files per thread: `-F 100` to `-F 1000`

#### Network Considerations
- For remote destinations, consider network bandwidth
- Monitor system resources (CPU, memory, network)
- Adjust thread count based on available cores

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

## Error Handling

The script includes comprehensive error checking:

- **Input Validation**: Verifies source/destination paths and parameters
- **Dependency Checking**: Ensures required utilities are installed
- **Permission Validation**: Checks read/write permissions
- **Remote Host Validation**: Basic hostname and path format checking
- **Size Validation**: Ensures minimum size requirements and valid units

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

4. **Performance Issues**
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

This script is provided as-is under the MIT License. See LICENSE file for details.

## References

- [FPart Project](http://www.fpart.org/#fpsync)
- [FPart GitHub Repository](https://github.com/martymac/fpart)
- [Rsync Manual](https://rsync.samba.org/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/bash.html)

## Version History

- **v1.2**: Current version with enhanced size parsing and validation
- **v1.1**: Added remote destination support
- **v1.0**: Initial release with basic functionality
