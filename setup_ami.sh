#!/bin/bash

# Install prerequisites
if [ -f /etc/debian_version ]; then
    echo "Detected Debian-based system."
    sudo apt update
    sudo apt install -y s3fs jq
elif [ -f /etc/redhat-release ]; then
    echo "Detected RHEL-based system."
    sudo yum install -y epel-release
    sudo yum install -y s3fs-fuse jq
else
    echo "Unsupported OS."
    exit 1
fi

# Configure AWS credentials
AWS_CREDENTIALS_FILE="$HOME/.aws/credentials"
mkdir -p "$(dirname "$AWS_CREDENTIALS_FILE")"

cat > "$AWS_CREDENTIALS_FILE" <<EOF
[default]
aws_access_key_id = AKIAWPXXXXXXS2D3Y
aws_secret_access_key = FKXXXXXXXXXXXXXXXXXXXTcVx
EOF

chmod 600 "$AWS_CREDENTIALS_FILE"
echo "AWS credentials configured at $AWS_CREDENTIALS_FILE."

echo "Setup complete."
