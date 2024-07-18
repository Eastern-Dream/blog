+++
title = ' Windows 10/11 QEMU guest simple GPU PCI passthrough guide'
date = 2024-07-17T19:14:12-04:00
draft = false
+++
# Introduction
This is a fast technical guide for GPU passthrough to Windows 10/11 VM on NixOS host. Non-NixOS system can still benefit from this guide, but no system configuration nor dependencies specified in here will be applicable so you will have to do-it-yourself.

This guide builds upon the an [older post about Windows QEMU guest provisioning](https://eastern-dream.github.io/blog/posts/nixos-windows-guest-graphical-improvement-filesystem-clipboard-sharing-guide/). There are a few assumptions which I will not provide guidance to check for:
- This guide is only for secondary GPU device that is used solely for passthrough.
- [The host system is capable of PCI passthrough](https://docs.redhat.com/en/documentation/red_hat_virtualization/4.2/html/installation_guide/host-requirements#Device_Assignment_Requirements_RHV_install).

If your system was built within the last decade or so, then it probably is passthrough capable.

# Get PCI Device ID
I will be using the details of my own GT 1030 that I actually use for passthrough. Of course yours might be different. Let us examine device ID, bus ID, IOMMU group, and kernel driver currently in use all with one command output:
```
$ nix-shell -p pciutils
$ lspci -vnnk
...
06:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP108 [GeForce GT 1030] [10de:1d01] (rev a1) (prog-if 00 [VGA controller])
        Subsystem: eVga.com. Corp. Device [3842:6335]
        Flags: bus master, fast devsel, latency 0, IRQ 192, IOMMU group 19
        Memory at a0000000 (32-bit, non-prefetchable) [size=16M]
        Memory at 4420000000 (64-bit, prefetchable) [size=256M]
        Memory at 4430000000 (64-bit, prefetchable) [size=32M]
        I/O ports at 4000 [size=128]
        Expansion ROM at a1000000 [disabled] [size=512K]
        Capabilities: <access denied>
        Kernel driver in use: nouveau
        Kernel modules: nvidiafb, nouveau

06:00.1 Audio device [0403]: NVIDIA Corporation GP108 High Definition Audio Controller [10de:0fb8] (rev a1)
        Subsystem: eVga.com. Corp. Device [3842:6335]
        Flags: bus master, fast devsel, latency 0, IRQ 17, IOMMU group 19
        Memory at a1080000 (32-bit, non-prefetchable) [size=16K]
        Capabilities: <access denied>
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel
...
```
In case you haven't noticed, basically all consumer GPUs comes with its own audio controller and that is presented as another device under the same bus ID. **Note down the device IDs**. Also pay attention to the driver in use if you are using NVIDIA GPU because the modprobe config later will depends on this.

# NixOS Host Configuration
Now that we have gotten a list of PCI device ID we want to passthrough, let us turn on IOMMU:
```
boot.kernelParams = [
    "intel_iommu=on"
];
```

AMD hosts do not have to bother with this since the kernel auto-detect IOMMU capabilities and turns it on by default. If it is not on for whatever reason and you are sure that your system is passthrough capable you can try:
```
boot.kernelParams = [
    "amd_iommu=on"
];
```

Enable VFIO kernel modules:
```
boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
];
```

Loads vfio-pci early and tell it to bind to our GPU:
```
boot.extraModprobeConfig = ''
    softdep drm pre: vfio-pci 
    options vfio-pci ids=10de:1d01,10de:0fb8 <-- You need to replace these device IDs with your own
'';
```
If you use NVIDIA proprietary driver then replace `softdep drm pre: vfio-pci` with `softdep nvidia pre: vfio-pci`. Rebuild and reboot.

### Check kernel driver

Here is what the post-config `lspci -vnnk` output looks like, note the kernel driver in use, the config is successful if it shows `vfio-pci`:
```
$ lspci -vnnk
...
06:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP108 [GeForce GT 1030] [10de:1d01] (rev a1) (prog-if 00 [VGA controller])
        Subsystem: eVga.com. Corp. Device [3842:6335]
        Flags: bus master, fast devsel, latency 0, IRQ 16, IOMMU group 19
        Memory at a0000000 (32-bit, non-prefetchable) [size=16M]
        Memory at 4420000000 (64-bit, prefetchable) [size=256M]
        Memory at 4430000000 (64-bit, prefetchable) [size=32M]
        I/O ports at 4000 [size=128]
        Expansion ROM at a1000000 [disabled] [size=512K]
        Capabilities: <access denied>
        Kernel driver in use: vfio-pci
        Kernel modules: nvidiafb, nouveau

06:00.1 Audio device [0403]: NVIDIA Corporation GP108 High Definition Audio Controller [10de:0fb8] (rev a1)
        Subsystem: eVga.com. Corp. Device [3842:6335]
        Flags: bus master, fast devsel, latency 0, IRQ 17, IOMMU group 19
        Memory at a1080000 (32-bit, non-prefetchable) [size=16K]
        Capabilities: <access denied>
        Kernel driver in use: vfio-pci
        Kernel modules: snd_hda_intel
...
```

Your GPU is now ready for PCI passthrough. In virt-manager you just add hardware and use the bus ID and canonical name to get a reference, remember to passthrough the corresponding audio controller device as well.

# Windows Guest Quirk
The way SPICE cursor works is that it actually renders the cursor on the client, and is made invisible inside the video stream. Because SPICE uses a virtual GPU, it isn't really designed to work in conjunction with a real GPU in the VM. The NVIDIA driver seems to load after the QXL / SPICE driver on boot, which consumes your mouse, taking control away from SPICE driver. Therefore, the solution is to toggle NVIDIA device on and off to run after you login, this gives the cursor control back to SPICE.

Create a PowerShell script with the following content, note that you need to replace the canonical GPU name string **exactly** as it would appears in Device Manager:
```
get-pnpdevice | where {$_.friendlyname -like "NVIDIA GeForce GT 1030"}| disable-pnpdevice -Confirm:$false
get-pnpdevice | where {$_.friendlyname -like "NVIDIA GeForce GT 1030"}| enable-pnpdevice -Confirm:$false 
```
Save file and **note the path to the script**. The script needs to be run at a high privilege everytime at system startup. Follow this procedure:
- Open Task Scheduler
- Click `Create Task...`
    - Name the task
    - Tick `Run with highest privileges`
- Click `Change User or Groups...`
    - Type `SYSTEM` into the text box
    - Click `Check Names`
    - Click `OK`
- Switch to `Triggers` tab, click `New...`
    - Choose to begin the task `At startup`
    - Click `OK`
- Switch to `Actions` tab, click `New...`
    - Paste the following path to the powershell executable into `Program/script:`
        - `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
    - Add the following into `Add arguments:`, note the path for the script that was created earlier
        - `-Executionpolicy Bypass -File "C:\Users\user-name\Desktop\toggle-gt1030-gpu.ps1"`
- Switch to `Conditions` tab
    - Untick `Start the task only of the computer is on AC power`
- Finally, click `OK` to finish task creation.

Can you believe it was that easy? I'll have you say...

![image](https://github.com/Eastern-Dream/blog/blob/main/static/easy.jpg?raw=true)