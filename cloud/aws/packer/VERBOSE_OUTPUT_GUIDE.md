# Verbose Output Guide for Packer Builds

## Overview
The Windows setup script ([`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1)) has been enhanced with comprehensive verbose output for all operations.

## Global Verbosity Settings

The script enables verbose output globally:
```powershell
$VerbosePreference = "Continue"  # Enable verbose output globally
$ProgressPreference = "Continue"  # Show progress bars
```

## Detailed Output Sections

### 1. Script Initialization
Shows:
- Script start timestamp
- PowerShell version
- Execution policy
- Environment information

### 2. Version Detection
Shows:
- Whether using environment variables or auto-detecting
- API calls to HashiCorp releases
- Latest version numbers fetched
- Final versions to be installed

### 3. Directory Structure Setup
Shows:
- Each directory being created
- Full paths
- Success confirmation with ✓ checkmarks
- Total directories created

**Example Output:**
```
========================================
Directory Structure Setup
========================================
Creating HashiCorp directory structure...
  Creating: C:\HashiCorp\bin
    ✓ Created successfully
  Creating: C:\HashiCorp\Consul
    ✓ Created successfully
  ...
All directories created successfully
```

### 4. HashiStack Component Downloads
Shows:
- Component name and version
- Full download URL
- HTTP request details (via `-Verbose` flag)
- Extraction progress
- Installation confirmation

**Example Output:**
```
[Consul] Downloading version 1.22.1...
  URL: https://releases.hashicorp.com/consul/1.22.1/consul_1.22.1_windows_amd64.zip
  VERBOSE: GET https://releases.hashicorp.com/consul/...
  VERBOSE: received 45.2MB of 45.2MB
  Download complete, extracting to C:\HashiCorp\bin...
[Consul] Installed successfully
```

### 5. PATH Configuration
Shows:
- Current PATH length
- Whether adding or already present
- New PATH length after modification
- Success confirmation

**Example Output:**
```
========================================
PATH Configuration
========================================
Configuring system PATH...
  Current PATH length: 1024 characters
  Adding C:\HashiCorp\bin to system PATH...
  ✓ PATH updated successfully
  New PATH length: 1048 characters
```

### 6. Installation Verification
Shows:
- Version check for each component
- Full version output from each binary
- Success confirmation

**Example Output:**
```
========================================
Installation Verification
========================================
Verifying installed components...

[Consul] Version check:
Consul v1.22.1
Revision 59b8b905
Build Date 2025-08-13T12:03:12Z
...

All components verified successfully!
```

### 7. Firewall Configuration
Shows:
- Progress counter (e.g., [1/14])
- Rule name, port, and protocol
- Success or skip status for each rule
- Total rules configured

**Example Output:**
```
========================================
Windows Firewall Configuration
========================================
Configuring firewall rules for HashiStack...

  [1/14] Creating rule: Consul HTTP (Port 8500/TCP)
    ✓ Rule created successfully
  [2/14] Creating rule: Consul DNS (Port 8600/TCP)
    ✓ Rule created successfully
  ...
  
Firewall configuration completed!
  Total rules configured: 15
```

### 8. Docker Installation
Shows:
- 4-step progress indicator
- Existing installation check
- Estimated time for each step
- Verbose PowerShell module operations
- Docker version after installation
- Detailed error messages if issues occur

**Example Output:**
```
========================================
Docker Installation
========================================
[1/4] Checking for existing Docker installation...
  Docker not found, proceeding with installation
[2/4] Installing DockerMsftProvider module from PSGallery...
  This may take a few minutes...
  VERBOSE: Installing package 'DockerMsftProvider'...
  VERBOSE: Package 'DockerMsftProvider' installed successfully
  ✓ DockerMsftProvider module installed successfully
[3/4] Installing Docker package...
  This may take 5-10 minutes depending on network speed...
  VERBOSE: Downloading Docker package...
  VERBOSE: Installing Docker...
  ✓ Docker package installed successfully
[4/4] Verifying Docker installation...
  Docker service found: Running
  Docker version:
  Client: Docker Engine - Community
   Version:           24.0.7
   ...

Docker installation completed successfully!
```

## Color Coding

The output uses color coding for easy reading:
- **Cyan**: Section headers and informational messages
- **Yellow**: In-progress operations
- **Green**: Success messages and checkmarks (✓)
- **Red**: Error messages
- **White**: Standard output and data

## Monitoring Real-Time Output

To see all this verbose output in real-time during a build:

```bash
# Start the build with output piped to a log file
packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl . 2>&1 | tee ./logs/build-$(date -u +"%Y%m%d-%H%M%S").out

# In another terminal, monitor the log
tail -f ./logs/build-*.out
```

## Benefits of Verbose Output

1. **Troubleshooting**: Immediately see where issues occur
2. **Progress Tracking**: Know exactly what's happening at each step
3. **Performance Monitoring**: See how long each operation takes
4. **Verification**: Confirm all components installed correctly
5. **Debugging**: Detailed error messages when things go wrong

## Future Enhancements

The verbose output can be further enhanced by:
- Adding timing information for each step
- Including file size information for downloads
- Showing network speed during downloads
- Adding system resource usage monitoring
- Including checksums verification for downloaded files