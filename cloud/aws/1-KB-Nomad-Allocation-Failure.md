## Problem Description

Users may experience widespread issues with allocations failing to place and go healthy on Nomad clients running on Windows. Specifically, once a client node reaches a certain number of allocations (approximately 24), the client may enter a frozen state.

Restarting the Nomad service or the VM itself often does not restore service; the only effective workaround prior to the permanent fix is to destroy and rebuild the underlying VM.

## Error Messages

When this issue occurs, the following warning and error messages are observed in the Nomad client logs: 

```
[WARN] client.driver_mgr: failed to reattach to plugin, starting new instance: driver=app_pool err="Reattachment process not found"
```

Later in the logs, or associated with driver failures, you may also see errors indicating insufficient resources:

```
error="failed to start plugin: failed to launch plugin: pipe: Insufficient system resources exist to complete the requested service."
```

## Root Cause

This issue is caused by the exhaustion of the **Desktop Heap** for non-interactive processes on Windows. 

Nomad and its task drivers (such as the `raw_exec` plugin or custom drivers like `app_pool`) run as background services. Each allocation or plugin instance consumes a portion of the non-interactive desktop heap. The default Windows configuration typically allocates a small amount of memory (often 768KB) to this heap, which can limit the number of concurrent subprocesses a service can spawn. When this limit is reached, Nomad cannot launch new plugins or reattach to existing ones, resulting in the "Reattachment process not found" and "Insufficient system resources" errors.

## Solution

To resolve this issue, you must increase the Desktop Heap size for non-interactive window stations in the Windows Registry.

### Steps to Fix

1. **Registry Path:** Navigate to the following registry key: 
   `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems`

2. **Key to Modify:** Locate the string value named `Windows`.

3. **Value Modification:** Inside the `Windows` string, look for the `SharedSection` segment. It usually looks like `SharedSection=1024,20480,768`.

   - The first value (`1024`) is the shared heap size common to all desktops.
   - The second value (`20480`) is the desktop heap size for the interactive window station (used by logged-on users).
   - **The third value (`768`) is the desktop heap size for the non-interactive window station (used by services).**

   **Action:** Increase the third value from the default (e.g., `768`) to a higher value, such as `4096`.

   **Example Updated Value:** `SharedSection=1024,20480,4096`

4. **Apply Changes:** Save the changes to the registry. 

5. **Restart:** A full system reboot of the Windows node is required for this change to take effect.

### PowerShell Script Example

You can apply this change using PowerShell:

```powershell
$heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows" -Value $heapLimits
```

*Note: Ensure the rest of the string matches your system's configuration before applying.*

## References

- [GitHub Issue #11939: raw_exec plugin windows: "logmon:  Unrecognized remote plugin message"](https://github.com/hashicorp/nomad/issues/11939)
- [GitHub Issue #6715](https://github.com/hashicorp/nomad/issues/6715)
- Windows "[desktop heap](https://docs.microsoft.com/en-us/archive/blogs/ntdebugging/desktop-heap-overview)"