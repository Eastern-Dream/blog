+++
title = 'NixOS Host Windows Guest Simple Looking Glass Setup Guide'
date = 2024-07-18T19:42:18-04:00
draft = false
+++
# Introduction
This is a fast technical guide for setting up [Looking Glass](https://looking-glass.io) on NixOS host and Windows guest. Non-NixOS system can still benefit from this guide, but no system configuration nor dependencies specified in here will be applicable so you will have to do-it-yourself.

This guide builds upon the an [older post about Windows guest GPU passthrough](https://eastern-dream.github.io/blog/posts/nixos-windows-guest-simple-gpu-pci-passthrough-guide/). It also will reference a lot to the [Looking Glass B7-rc1 documentations](https://looking-glass.io/docs/B7-rc1/). At the time of writing, version B7-rc1 is highly recommended, so that is what we will use.

**All of this requires that you already have a bootable VFIO passthrough setup working correctly!** There will also be no performance tuning here beyond what is already covered by LG docs. This guide also assumes this [specific ideal system hardware outlined in the LG docs](https://looking-glass.io/docs/B7-rc1/requirements/#recommended). Any fixes for quirks resulting from non-optimal system hardware is not considered in this guide.

# NixOS Host Configuration
NixOS gets first-class support for Looking Glass as the `kvmfr` module and `looking-glass-client` is already in nixpkgs! The kernel module reference changes depending on which kernel you use. If you don't already know how to do it, you need to use the `config` attribute set and reference it like so:
```
{ config , ... }:

{
    boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
    boot.kernelModules = [ "kvmfr" ];
}
```
The default 32MB memory region is enough up to 1440p SDR, read the docs if your use case is different and adjust modprobe config accordingly.

[The Looking Glass documentation has a permission setup for the KVMFR interface](https://looking-glass.io/docs/B7-rc1/ivshmem_kvmfr/#permissions). We can perform the same step by adding:
```
services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="user", GROUP="kvm", MODE="0660"
'';
```
You must replace `user` with your own username! 

Additionally, we must get around the [cgroups issue here](https://looking-glass.io/docs/B7-rc1/ivshmem_kvmfr/#cgroups) because the VM will be using `/dev/kvmfr0`. Add the following to your config:
```
virtualisation.libvirtd.qemu.verbatimConfig = ''
    cgroup_device_acl = [
        "/dev/null", "/dev/full", "/dev/zero",
        "/dev/random", "/dev/urandom",
        "/dev/ptmx", "/dev/kvm",
        "/dev/kvmfr0"
    ]
'';
```

Alternatively, you can also omit `devices` cgroup completely:
```
virtualisation.libvirtd.qemu.verbatimConfig = ''
    cgroup_controllers = [ "cpu", "memory", "blkio", "cpuset", "cpuacct" ]
'';
```

Lastly, we need the Looking Glass client, simply add `looking-glass-client` package. Rebuild and reboot.

# Guest Setup
### Virtual Hardware Setup
Do **all** the following suggested setup from LG docs:
- https://looking-glass.io/docs/B7-rc1/ivshmem_kvmfr/#libvirt
- https://looking-glass.io/docs/B7-rc1/install_libvirt/#keyboard-mouse-display-audio
- https://looking-glass.io/docs/B7-rc1/install_libvirt/#memballoon

There are a few things you need to lookout for:
- You need to edit the XML to add `xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0"` to the `<domain>` tag AND the QEMU commandline XML block at the same time!
- Re-check `Boot Options` if you are using virt-manager, after XML edit it reset all the options, leaving my VM unbootable.
- Note that for clipboard synchronization is already setup correctly if this was the same VM created using my guides.

### Ensure you have a valid output
The overly simplified way to explain how LG works is that it literally copy the GPU output and passes it to Linux LG client application. Windows requires that a GPU to be connected to a display to have an output. If there are no display output, then Windows disable the GPU and there would be nothing for LG to capture the display output. The typical solution is a HDMI dummy plug or software solution like a virtual/fake display to trick Windows into thinking it has a display output.

But let's be real, if you have a dual GPU workstation, you have a nearby monitor that has multiple inputs. Might as well make the output exists for real by plugging the GPU into the monitor. It also doubles as a fallback display in case Looking Glass fails for whatever reason by just switching your connected monitor input.

The only limitation to this approach is that your output is limited by the native resolution and refresh rate of the monitor that the passthrough GPU is plugged in.

### Install Looking Glass Host
Download the B7-rc1 Windows host binary and install it on the guest. Here is some [reference in the docs](https://looking-glass.io/docs/B7-rc1/install_host/#installing-the-looking-glass-service). Unsure if a VM reboot is needed post-installation but it is probably a good idea anyhow. 

After VM has fully booted, first check the host application log to see if it is running correctly. Only then, run the client from your terminal with `looking-glass-client -f /dev/kvmfr0`.

Can you believe it was that easy? I'll have you say...

![image](https://github.com/Eastern-Dream/blog/blob/main/static/easy.jpg?raw=true)
