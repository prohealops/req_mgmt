#!/bin/bash

# ----------------------------
# Config Section
# ----------------------------
BUCKET_NAME="ank-courier-healops"
MOUNT_POINT="/home/ubuntu/s3bucket1"
S3_URL="https://s3.amazonaws.com"
LOG_FILE="/var/log/s3_mount.log"
# ----------------------------

# Timestamp function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "==== Starting S3 bucket mount script ===="

# Check if s3fs is installed
if ! command -v s3fs >/dev/null 2>&1; then
    log "s3fs not installed. Exiting."
    exit 1
fi

# Check if mount point exists, create if not
if [ ! -d "$MOUNT_POINT" ]; then
    log "Mount point $MOUNT_POINT does not exist. Creating..."
    mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mount | grep "on $MOUNT_POINT type fuse.s3fs" > /dev/null; then
    log "Bucket already mounted on $MOUNT_POINT"
else
    log "Mounting bucket $BUCKET_NAME to $MOUNT_POINT"
    s3fs "$BUCKET_NAME" "$MOUNT_POINT" 

    if [ $? -eq 0 ]; then
        log "Successfully mounted $BUCKET_NAME"
    else
        log "Mount failed. Check credentials or network."
    fi
fi

log "==== Script finished ===="