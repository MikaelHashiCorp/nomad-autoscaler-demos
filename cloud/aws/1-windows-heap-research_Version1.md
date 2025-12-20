# Windows Desktop Heap Limits and Nomad Logmon Issue Research

## Executive Summary

This document provides research findings on Windows Server desktop heap default values and the current status of the Nomad logmon issue related to Windows desktop heap limitations.  The key finding is that the workaround described in the original document remains necessary as the underlying issue has not been resolved in Nomad's codebase.

## Windows Desktop Heap Default Values

### Overview

The Windows desktop heap is a memory allocation used by the Windows subsystem to store window objects for each desktop.  Services running under non-interactive window stations have a limited heap size, which can cause issues when spawning many subprocesses. 

### Default Values by Windows Server Version

| Windows Server Version | Release Year | Default SharedSection Value | Non-Interactive Service Heap (KB) |
|------------------------|--------------|----------------------------|----------------------------------|
| Windows Server 2016    | 2016         | `1024,20480,768`          | 768                              |
| Windows Server 2019    | 2018         | `1024,20480,768`          | 768                              |
| Windows Server 2022    | 2021         | `1024,20480,768`          | 768                              |
| Windows Server 2025    | 2024         | `1024,20480,768`          | 768                              |

### SharedSection Parameter Breakdown

The `SharedSection` parameter in the Windows registry consists of three values: 

1. **First value (1024 KB)**: Shared heap for all desktops
2. **Second value (20480 KB)**: Desktop heap size for interactive window stations (user sessions)
3. **Third value (768 KB)**: Desktop heap size for non-interactive window stations (services) - **This is the critical value for Nomad**

### Registry Location

```
HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems\Windows
```

### Why This Matters for Nomad

Nomad runs as a Windows service, placing it in the non-interactive window station category. Each allocation spawned by Nomad consumes desktop heap space. With the default 768 KB limit, users typically encounter issues after 40-60 allocations, manifesting as the error:

```
logmon: Unrecognized remote plugin message:  This usually means that the plugin is either invalid or simply needs to be recompiled to support the latest protocol. 
```

## Nomad Logmon Issue Status

### Current Status

- **GitHub Issue**: [#11939 - raw_exec plugin windows:  "logmon: Unrecognized remote plugin message"](https://github.com/hashicorp/nomad/issues/11939)
- **Status**: **OPEN** (as of December 2025)
- **Created**: January 26, 2022
- **Last Updated**: June 24, 2024

### Timeline

1. **January 26, 2022**: Issue reported by user experiencing intermittent logmon failures on Windows Server 2016
2. **January 29, 2022**: User identified correlation with number of allocations and Windows service subprocess limits
3. **February 1, 2022**: User confirmed the Windows desktop heap was the root cause and documented the workaround

### Code Analysis

Based on analysis of the Nomad repository: 

- **No desktop heap handling**:  The logmon code does not contain any logic to detect or handle Windows desktop heap limitations
- **No automatic mitigation**:  Nomad does not automatically adjust heap limits or provide warnings when approaching limits
- **Recent changes**: A recent update (changelog 24798) improved plugin validation during reattach, but this addresses reliability, not the heap limitation itself

### Why This Hasn't Been "Fixed"

This is fundamentally a **Windows OS limitation**, not a Nomad bug. The issue cannot be fully resolved at the application level because:

1. Services cannot modify their own desktop heap allocation at runtime
2. The heap limit is set system-wide via the Windows registry
3. Changing the limit requires administrator privileges and a system restart
4. The appropriate limit depends on the specific workload and server configuration

## Recommended Solution

### PowerShell Script to Increase Heap Limit

The following script increases the desktop heap limit from 768 KB to 4096 KB: 

```powershell
# Increase service heap limit, controlling how many subprocesses a service can spawn
$heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows=On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows" -Value $heapLimits
```

**Important**:  A system restart is required for this change to take effect.

### Verification

After restarting, verify the change with:

```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows"
```

## Considerations and Caveats

### Resource Impact

- **Memory Usage**:  Increasing the heap limit allows all services to potentially use more memory
- **System-Wide Effect**: The change affects all Windows services, not just Nomad
- **Monitoring**: Monitor overall system memory usage after implementing this change

### When to Apply This Fix

Apply this workaround if you experience: 

- The "logmon: Unrecognized remote plugin message" error
- Failures starting allocations after 40-60+ allocations are running
- Issues that resolve temporarily when allocations are stopped and restarted

### Alternative Values

While the documented solution uses 4096 KB, you may adjust based on your needs:

- **2048 KB**: For moderate workloads (100-120 allocations)
- **4096 KB**: For heavy workloads (200+ allocations) - **Recommended**
- **8192 KB**: For extreme workloads (requires careful monitoring)

⚠️ **Warning**: Setting the value too high may cause excessive memory consumption.  Microsoft recommends not exceeding 20 MB (20480 KB) for this parameter.

## References

- [Nomad GitHub Issue #11939](https://github.com/hashicorp/nomad/issues/11939)
- [Microsoft:  Desktop Heap Overview](https://docs.microsoft.com/en-us/archive/blogs/ntdebugging/desktop-heap-overview)
- [Stack Overflow: Service Child Process Limits](https://stackoverflow.com/questions/17472389/how-to-increase-the-maximum-number-of-child-processes-that-can-be-spawned-by-a-w)

## Conclusion

**The workaround documented in the original windows-heap. md file is NOT obsolete and remains necessary for production Nomad deployments on Windows Server.**

As of December 2025:
- The issue remains open in the Nomad GitHub repository
- No code-level fix has been implemented in Nomad
- The Windows desktop heap limitation is an OS-level constraint
- Users must manually apply the registry modification to support high allocation counts

Organizations running Nomad on Windows Server should include this registry modification in their server provisioning scripts or infrastructure-as-code templates. 

---

**Document Version**: 1.0  
**Last Updated**: December 19, 2025  
**Research Conducted By**: GitHub Copilot  
**Original Issue Reference**: hashicorp/nomad#11939