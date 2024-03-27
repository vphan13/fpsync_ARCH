# fpsync_ARCH

This is a wrapper script for the fpsync utility that comes with the fpart tool. It simplifies the most common fpsync tasks.\
It can be used to copy large datasets of very small files.
Please refer to the [fpsync documentation](https://www.fpart.org/fpsync/) for more options

## Prerequisites
The fpart utility must be installed and located in your $PATH\
[fpart documentation](https://www.fpart.org/)

[fpart RPM for RHEL/Rocky 9](https://kojipkgs.fedoraproject.org//packages/fpart/1.5.1/1.el9/x86_64/fpart-1.5.1-1.el9.x86_64.rpm)

A 10Gb connection



## Installation
Download the fpsync_ARCH.sh file and place it in your $PATH
chown +x fpsync_ARCH.sh

Usage:
        fpsync_ARCH Takes the following 3 optional options and source and destination paths
        if no options are provided, defaults in [ ] are used\
        -T: Number of rsync threads     [15]\
        -S: Size (In GB) per thread     [6]\
        -F: Number of files per thread  [2500]

Example:
        fpsync_ARCH <src directory> <destination directory>

       fpsync_ARCH /home/users1/<username>/<flowcell> /home/users2/<username>/<flowcell>

Override defaults using:

        fpsync_ARCH -T 25 -S 10 -F 5000 /home/users1/<username>/<flowcell> /home/users2/<username>/<flowcell>

        - 25 concurrent threads (override using the -T option)
        - copying 10 GB of data per thread (override using the -S option in GB)
        - maximum of 5000 files per thread (override using the -F -option)


Generally speaking, when copying lots of small files, its best to reduce the amount of data (-S) and increase the number of
concurrent rsync threads (-T) and limit how many files per thread (-F) to ensure there is enough data being copied concurrently to fill your
bandwidth.  The bottleneck will likely be your disk io.  

fpsync_ARCH.sh is fastest from local disk to nfs mounted path, but can also be used over ssh

  ```fpsync_ARCH -T 25 -S 10 -F 5000 /home/users1/<username>/<flowcell> username@hostname:/home/users2/<username>/<flowcell>```

This option is considerably slower to due to encryption overhead

Refer to the fpsync man page for more granular options

Logging for all rsync threads for the above example would be located under /tmp/fpart-log/\<username\>-\<flowcell\>
