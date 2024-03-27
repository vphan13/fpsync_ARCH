#!/bin/bash

#################################
#    fpsync wrapper script	#
#    Written by Vinh Phan 	#
#################################

MAILTO=""
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
export PATH=$SCRIPTPATH:$PATH
LOGDIR=/tmp/fpart-log
SRC_DIR=$1
DEST_DIR=$2
THREADS="${THREADS:-15}"
# 6GB per rsync thread
SIZE="${SIZE:-$((6 * 1024 * 1024 * 1024))}"
BSIZE="${BSIZE:-6}"


# MAX number of files per rsync thread
FILES="${FILES:-2500}"

fpsync-it () {
# check if fpart and fpsync is in your path

    echo "Running fpsync-it"
    export starttime=$(date +%Y-%m-%d)_$(date +%T)
# Get the last 2 directories of the source path and
# name the run log directory after them
D2=$(dirname "$SRC_DIR")
RUNLOG="${LOGDIR}"/$(basename "${D2}")-$(basename "${SRC_DIR}")

    mkdir -p "${RUNLOG}"
    echo "Active logs are located under ${RUNLOG}"

echo "
Copying $SRC_DIR to $DEST_DIR using 
	- $THREADS threads
	- maximum of $FILES files per thread
	- maximum of $BSIZE GB per thread 
	- log files are located at $RUNLOG
"
#    fpsync -v -n 20 -f 2500 -s $((4 * 1024 * 1024 * 1024)) -d "${RUNLOG}" "${SRC_DIR}" "${DEST_DIR}" -M "${MAILTO}"
#    echo "fpsync  -v -n ${THREADS} -f ${FILES} -s ${SIZE} -d ${RUNLOG} ${SRC_DIR} ${DEST_DIR}"
    fpsync  -v -n ${THREADS} -f ${FILES} -s ${SIZE} -d ${RUNLOG} ${SRC_DIR} ${DEST_DIR}
}


help () {
cat << EOL

This is a wrapper script for the fpsync utility included with the fpart utility.
For more info please read the docs at http://www.fpart.org/#fpsync or download at
https://kojipkgs.fedoraproject.org//packages/fpart/1.5.1/1.el9/x86_64/fpart-1.5.1-1.el9.x86_64.rpm

It is used to copy large directory trees with lots of files

Prerequisites: This script reaches the highest throughput when the source/destination directories are locally hosted
or nfs mounted. 

If running against a remote host, SSH key access as well as the prelogin banner needs to be disabled
The fpart and fpsync utility also need to be in your PATH: https://github.com/martymac/fpart.git

$0 syntax is similiar to rsync, however,
the source directory must be included in the destination path

Usage: 
	$0 Takes the following 3 optional options and source and destination paths
	if no options are provided, defaults in [ ] are used
	-T: Number of rsync threads	[15] 
	-S: Size (In GB) per thread	[6]
	-F: Number of files per thread  [2500]
	

Example:
        $0 <src directory> <destination directory>

        $0 /home/users1/<username>/<flowcell> /home/users2/<username>/<flowcell>

By default $0 is configured to use:
        - $THREADS concurrent threads (override using the -T option)
        - copying ${BSIZE} GB of data per thread (override using the -S option in GB)
        - maximum of ${FILES} files per thread (override using the -F -option)

Override defaults using:

        $0 -T 25 -S 10 -F 5000 /home/users1/<username>/<flowcell> /home/users2/<username>/<flowcell>

        - 25 concurrent threads (override using the -T option)
        - copying 10 GB of data per thread (override using the -S option in GB)
        - maximum of 5000 files per thread (override using the -F -option)


Generally speaking, when copying lots of small files, its best to reduce the amount of data (-S) and increase the number of
concurrent rsync threads (-T) and limit how many files per thread (-F) to ensure maximum number of threads can fill your 
bandwidth

Refer to the fpsync man page or change the options under the fpsync-it function below

EOL
exit 2
}

while getopts 'HT:F:S:' OPTION; do
   case "$OPTION" in
        T)
           THREADS=$OPTARG
           ;;
        F)
           FILES=$OPTARG
           ;;
        S)
           BSIZE=$OPTARG
           SIZE=$((${BSIZE} * 1024 * 1024 * 1024))
           ;;

        H | *)
           help

           ;;
   esac
done

SRC_DIR=${@:$OPTIND:1}
DEST_DIR=${@:$OPTIND+1:1}

fpsync-it
