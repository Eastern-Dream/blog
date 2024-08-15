+++
title = 'NixOS Host Windows 10/11 QEMU Guest Simple Looking Glass Setup Guide'
date = 2024-07-18T19:42:18-04:00
draft = false
+++
# Introduction
This is a fast technical guide for setting up [Looking Glass](https://looking-glass.io) on NixOS host and Windows guest. Non-NixOS system can still benefit from this guide, but no system configuration nor dependencies specified in here will be applicable so you will have to do-it-yourself.

This guide builds upon the an [older post about Windows guest GPU passthrough](https://eastern-dream.github.io/blog/posts/nixos-windows-guest-simple-gpu-pci-passthrough-guide/). It also will reference a lot to the [Looking Glass Official Documentations](https://looking-glass.io/docs/B6/). At the time of writing, version B7-rc1 is highly recommended, so that is what we will use.

All of this requires that you already have a VFIO passthrough setup working correctly! There will also be no performance tuning here beyond what is already covered by LG docs. This guide also assumes this [specific ideal system hardware outlined in the LG docs](https://looking-glass.io/docs/B6/requirements/#recommended). Any fixes for quirks resulting from non-optimal system hardware is not considered in this guide.

# NixOS Host Configuration
You need the `kvmfr` kernel module, but the package reference changes depending on which kernel you use. I use Zen kernel so this is what it looks like:
```
boot.extraModulePackages = [ pkgs.linuxKernel.packages.linux_zen.kvmfr ];
```
Please make sure you reference the correct `kvmfr` module for your specific kernel. The default 32MB memory region is enough up to 1440p and a bit more, read the docs if your use case is different and adjust modprobe config accordingly.

[The Looking Glass documentation mentions a permission issue with the shared memory file](https://looking-glass.io/docs/B6/install/#permissions). We can perform the same step by adding:
```
systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 user kvm -" <-- replace 'user' with your actual user name!
];
```

Lastly, we need the Looking Glass client, simply add `looking-glass-client` package to either user or system package. Rebuild and reboot.

# Guest Setup
### Install Looking Glass Host
Before we make hardware changes to the guest, download the B7-rc1 Windows host binary and install it on the guest. We haven't set up LG on the virtual hardware side of things yet but you will probably lose control of the graphical console later so better to do it now.

### Plug the passthrough GPU into your monitor
You heard that right... Looking Glass host requires an existing display output to capture. If there are no display output, then Windows disable the GPU and there would be nothing to capture. The typical solution is a HDMI dummy plug or software solution like a virtual/fake display to trick the guest into thinking it has a display output. But let's be real, if you have a dual GPU system, you have a nearby monitor that has multiple inputs. Might as well make the output exists for real by plugging the GPU into the monitor. It also doubles as a fallback display in case Looking Glass fails for whatever reason by just switching your connected monitor input.

### Virtual Hardware Setup
Do all the following suggested setup from LG docs:
- https://looking-glass.io/docs/B6/install/#configuration
- https://looking-glass.io/docs/B6/install/#keyboard-mouse-display-audio
- https://looking-glass.io/docs/B6/install/#memballoon

Note that for clipboard synchronization is already setup correctly if this was the same VM created using my guides.

The next time you boot up the VM, you probably won't be able to see the main display because Windows would set the output from the GPU to be the main display. But that doesn't matter as running `looking-glass-client` on your host terminal should work and give you a clear, crisp display output from the guest.

Can you believe it was that easy? I'll have you say...

![image](https://github.com/Eastern-Dream/blog/blob/main/static/easy.jpg?raw=true)