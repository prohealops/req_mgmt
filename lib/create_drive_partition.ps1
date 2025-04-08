# Variables
$DriveLetter = "Z"
$S3BucketName = "example-bucket-name"
$SamPassword = "P@ssw0rd123"
$UserName = "Sam"

# Function to create a local user
function Create-LocalUser {
  param (
    [string]$UserName,
    [string]$Password
  )
  if (-not (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    New-LocalUser -Name $UserName -Password $SecurePassword -PasswordNeverExpires -UserMayNotChangePassword
    Write-Host "User '$UserName' created successfully."
  } else {
    Write-Host "User '$UserName' already exists."
  }
}

# Function to install AWS CLI if not installed
function Install-AWSCLI {
  if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI is not installed. Installing AWS CLI..."
    $InstallerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $InstallerPath = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
    Start-Process msiexec.exe -ArgumentList "/i", $InstallerPath, "/quiet", "/norestart" -Wait
    Remove-Item $InstallerPath
    Write-Host "AWS CLI installed successfully."
  } else {
    Write-Host "AWS CLI is already installed."
  }
}

# Function to create a partition with the specified drive letter
function Create-Partition {
  param (
    [string]$DriveLetter
  )
  $Disk = Get-Disk | Where-Object IsOffline -eq $false | Where-Object PartitionStyle -eq "RAW" | Select-Object -First 1
  if ($null -eq $Disk) {
    Write-Error "No unallocated disk found to create a partition."
    return
  }

  Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -Confirm:$false
  New-Partition -DiskNumber $Disk.Number -UseMaximumSize -AssignDriveLetter:$false | Out-Null
  Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -Confirm:$false
  Write-Host "Partition created and formatted with drive letter '$DriveLetter'."
}

# Function to mount S3 bucket as a drive
function Mount-S3Bucket {
  param (
    [string]$DriveLetter,
    [string]$BucketName
  )
  # Create a directory for the S3 bucket mount
  $MountPoint = "C:\S3Mount\$BucketName"
  if (-not (Test-Path $MountPoint)) {
    New-Item -ItemType Directory -Path $MountPoint | Out-Null
  }

  # Mount the S3 bucket using AWS CLI
  $MountCommand = "aws s3 sync s3://$BucketName $MountPoint"
  Invoke-Expression $MountCommand

  # Assign the drive letter
  New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $MountPoint -Persist
  Write-Host "S3 bucket '$BucketName' mounted to drive '$DriveLetter:' successfully."
}

# Function to set permissions for the user
function Set-DrivePermissions {
  param (
    [string]$DriveLetter,
    [string]$UserName
  )
  $DrivePath = "$DriveLetter`:\"
  $Acl = Get-Acl $DrivePath
  $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:COMPUTERNAME\$UserName", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
  $Acl.SetAccessRule($AccessRule)
  Set-Acl -Path $DrivePath -AclObject $Acl
  Write-Host "Permissions set for user '$UserName' on drive '$DriveLetter:'."
}

# Main script execution
try {
  # Install AWS CLI if not installed
  Install-AWSCLI

  # Create the user
  Create-LocalUser -UserName $UserName -Password $SamPassword

  # Create a partition with the specified drive letter
  Create-Partition -DriveLetter $DriveLetter

  # Mount the S3 bucket
  Mount-S3Bucket -DriveLetter $DriveLetter -BucketName $S3BucketName

  # Set permissions for the user
  Set-DrivePermissions -DriveLetter $DriveLetter -UserName $UserName
} catch {
  Write-Error "An error occurred: $_"
}