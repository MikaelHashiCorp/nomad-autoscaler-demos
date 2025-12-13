#!/usr/bin/env python3
"""
Install Docker on Windows EC2 instance via WinRM
Requires: pip install pywinrm requests
"""

import sys
import subprocess
import json

# Configuration
INSTANCE_ID = "i-0363b8ece02ab1221"
REGION = "us-west-2"
PUBLIC_IP = "54.203.125.163"
WINRM_PORT = 5985

print("=" * 60)
print("Docker Installation via WinRM")
print("=" * 60)
print(f"\nInstance: {INSTANCE_ID}")
print(f"IP: {PUBLIC_IP}")
print(f"WinRM Port: {WINRM_PORT}\n")

# Check if pywinrm is installed
try:
    import winrm
    print("✓ pywinrm is installed")
except ImportError:
    print("✗ pywinrm is not installed")
    print("\nInstalling pywinrm...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pywinrm", "requests-ntlm"])
    import winrm
    print("✓ pywinrm installed successfully")

print("\n" + "=" * 60)
print("Getting Windows Password")
print("=" * 60)

# Get password data from AWS
try:
    result = subprocess.run(
        ["bash", "-c", f"source ~/.zshrc 2>/dev/null && aws ec2 get-password-data --instance-id {INSTANCE_ID} --region {REGION} --output json"],
        capture_output=True,
        text=True,
        check=True
    )
    password_data = json.loads(result.stdout)
    
    if not password_data.get('PasswordData'):
        print("✗ Password data is not yet available")
        print("\nPlease wait a few more minutes and try again.")
        sys.exit(1)
    
    print("✓ Password data is available")
    print("\nNote: Password is encrypted and requires the private key to decrypt.")
    print("Since we don't have access to the private key in this environment,")
    print("we cannot automatically decrypt the password.\n")
    
except Exception as e:
    print(f"✗ Error getting password data: {e}")
    sys.exit(1)

print("=" * 60)
print("Manual Steps Required")
print("=" * 60)
print("""
Since automated WinRM connection requires the decrypted password,
please follow these steps:

1. Get the decrypted password:
   - Go to AWS Console -> EC2 -> Instances
   - Select instance {INSTANCE_ID}
   - Click 'Connect' -> 'RDP client' -> 'Get Password'
   - Upload your key pair file (.pem) to decrypt

2. Once you have the password, you can either:

   Option A: Connect via RDP and run the PowerShell script manually
   - Host: {PUBLIC_IP}
   - Username: Administrator
   - Password: (from step 1)
   - Open PowerShell as Administrator
   - Copy and paste the contents of install-docker-windows.ps1

   Option B: Use this Python script with the password
   - Run: python3 install-docker-via-winrm.py --password YOUR_PASSWORD

3. The Docker installation script will:
   - Try DockerMsftProvider method first
   - Fall back to direct download if needed
   - Configure Docker service
   - Verify installation

""".format(INSTANCE_ID=INSTANCE_ID, PUBLIC_IP=PUBLIC_IP))

# Check if password was provided as argument
if len(sys.argv) > 2 and sys.argv[1] == '--password':
    password = sys.argv[2]
    print("\n" + "=" * 60)
    print("Attempting WinRM Connection")
    print("=" * 60)
    
    try:
        # Read the Docker installation script
        with open('install-docker-windows.ps1', 'r') as f:
            docker_script = f.read()
        
        # Create WinRM session
        print(f"\nConnecting to {PUBLIC_IP}:{WINRM_PORT}...")
        session = winrm.Session(
            f'http://{PUBLIC_IP}:{WINRM_PORT}/wsman',
            auth=('Administrator', password),
            transport='ntlm'
        )
        
        print("✓ Connected successfully")
        print("\nExecuting Docker installation script...")
        print("This may take several minutes...\n")
        
        # Execute the script
        result = session.run_ps(docker_script)
        
        print("=" * 60)
        print("Script Output")
        print("=" * 60)
        print(result.std_out.decode('utf-8'))
        
        if result.std_err:
            print("\n" + "=" * 60)
            print("Errors (if any)")
            print("=" * 60)
            print(result.std_err.decode('utf-8'))
        
        print("\n" + "=" * 60)
        print(f"Exit Code: {result.status_code}")
        print("=" * 60)
        
        if result.status_code == 0:
            print("\n✓ Docker installation completed successfully!")
        else:
            print("\n✗ Docker installation failed. Check the output above for details.")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nTroubleshooting:")
        print("1. Verify the password is correct")
        print("2. Ensure WinRM is accessible (check security group)")
        print("3. Try connecting via RDP manually")
        sys.exit(1)

else:
    print("\nTo use automated installation, run:")
    print(f"  python3 {sys.argv[0]} --password YOUR_DECRYPTED_PASSWORD")
    print("\nOr connect via RDP and run the script manually (recommended).")

print("\n" + "=" * 60)
print("Instance Information")
print("=" * 60)
print(f"Instance ID: {INSTANCE_ID}")
print(f"Public IP: {PUBLIC_IP}")
print(f"Region: {REGION}")
print(f"RDP Port: 3389")
print(f"WinRM Port: {WINRM_PORT}")
print("\nTo terminate instance when done:")
print(f"  source ~/.zshrc && logcmd aws ec2 terminate-instances --instance-ids {INSTANCE_ID} --region {REGION}")
print("=" * 60)

# Made with Bob
