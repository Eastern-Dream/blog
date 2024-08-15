+++
title = 'Fast provision of Windows 10/11 QEMU guest with filesystem and clipboard sharing through virt-manager'
date = 2024-06-28T16:59:21-04:00
draft = false
+++
# Introduction
This is a fast technical guide to setting up a Windows 10/11 VM on NixOS host. Non-NixOS system can still benefit from this guide, but no system configuration nor dependencies specified in here will be applicable so you will have to do-it-yourself.

We'll use virt-manager to quickly provision a Windows guest with VirtIO drivers and SPICE guest tools for performance, enhanced clipboard, and filesystem integration. This guide, and other guides of the same topics as well, assumes that you have familiarity with virtualization technologies and Linux.

One of the key tools we'll leverage is `autounattend.xml`, a configuration file that automates the Windows installation process. Instead of manually clicking through setup dialogs, `autounattend.xml` handles the installation parameters for you, significantly speeding up the provisioning of your VM. This automation not only saves time but also ensures a consistent setup every time.

### General Prerequisite
You are going to need to download a couple things before we get to work on the fast provision:
- Windows 10/11 ISO from Microsoft. Get it however you want but [directly from Microsoft](https://www.microsoft.com/software-download/windows11) works best.
- [Windows VirtIO Drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/). Navigate to the directory of the latest version and choose the disc image `virtio-win.iso`
- [SPICE Windows Guest Tools](https://www.spice-space.org/download.html). The download link can be found under the Windows binaries section.
- [Windows File System Proxy (WinFsp)](https://winfsp.dev/). This is a Windows FUSE driver and is needed for virtiofs guest driver to work.

### NixOS Host Configuration
[Follow the wiki](https://nixos.wiki/wiki/Virt-manager) to rebuild NixOS configuration to enable virt-manager, libvirtd, and a couple extra steps to make sure QEMU connection and network bridge is active. Additionally, for filesystem sharing you will need `virtiofsd` package in `environment.systemPackages`. Don't forget to reboot!

# Generate `autounattend.xml`
The Windows installation process is a PITA, even more so on virtual machine. Microsoft provides technical documentation of how Windows installer interacts with answer file [here](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs?view=windows-11). Basically, all we have to do is mount a disc image with `autounattend.xml` along with the Windows installation disc image and it will work.

So how exactly are we supposed to obtain a valid answer file? Luckily, a kind soul have made an [easy-to-use generator online](https://schneegans.de/windows/unattend-generator/) with exhaustive addition and explanation. For the purpose of this guide, it is required to have these options enabled in the generator:
- `Bypass Windows 11 requirements check (TPM, Secure Boot, etc.)`
- `Install VirtIO Guest Tools and QEMU Guest Agent (e.g. for Proxmox VE)`

It is highly recommended to read through every options that the generator offers and highly encouraged to make the answer file to the point of completely unattended installation. The default form is only missing this specific option to make it fully unattended:
- `Let Windows Setup wipe, partition and format your hard drive (more specifically, disk 0) using these settings:`

### Package Disc Image
We need to package the answer file into a disc image. We also have SPICE guest tools and WinFsp installer that we needed to pass to the guest OS anyway. Let's also package that in the same disc image along with the answer file for convenience. First, put all those three things into its own directory, remember the path. There are many ways to create disc image from file(s). Here is the method that I used, note the last trailing slash at the end:
```
$ nix-shell -p libisoburn
$ xorriso -outdev /path/to/output/unattend.iso -map /path/to/dir-containing-answer-file-and-guest-tools/ /
```

# Creating Virtual Machine
Before we start the VM creation. Make sure XML editing is enabled under Edit > Preferences > General.

Create a new virtual machine in virt-manager. Follow these steps:
- Choose manual install. Because sometimes virt-manager fails to automatically detect the correct OS.
- Choose Windows 10/11 depend on which installation image you have.
- Choose memory and CPU settings. Recommended to leave it at default.
- Choose storage. Configure this to your preference.
- Make sure to have `Customize configuration before install` checked, this will let us edit the hardware before starting installation.

# Hardware Setup
Libvirtd don't know where `virtiofsd` is on NixOS. So we gotta find it and specify the binary path for it. You will specify the correct path later in virt-manager.
```
$ which virtiofsd
/run/current-system/sw/bin/virtiofsd
```

Follow through each section below in order:
- CPUs
    - Manually set CPU topology of **1 socket, at least 4 cores, and 1 thread**. This is because the default topology is to emulate as many sockets as there are vCPUs allocation. However, [Windows impose an artificial limit on the number of sockets per edition](https://superuser.com/questions/959888/how-many-cpu-sockets-does-windows-10-support).
- Memory
    - Make sure `Enable shared memory` is enabled. This is required by virtiofs driver.
- Add Hardware  > `Filesystem`
    - In the XML tab, add line `<binary path="/run/current-system/sw/bin/virtiofsd"/>` to inner node.
- Add Hardware  > `Storage`
    - Device type `CDROM device`
    - Specify the disc image location for our Windows installation.
    - Repeat this add hardware process, but with the `unattend.iso` that we packaged previously (or however you named it), and `virtio-win.iso`.
- Boot Options
    - Tick the checkbox of the CDROM device containing the Windows installation image.

### During installation
You can now click begin installation. You will see the typical `Press any key to boot from CD or DVD...` prompt. **Do not skip this step**, enter the graphical console and press any key as instructed. Otherwise it will take you to the EFI interactive shell and you need to reboot the VM until you can respond to the prompt in time and enter Windows setup. All that is to do now is to take a break and wait for unattended installation process.

# Setup Within Guest
Open the disc drive containing our SPICE guest tools and WinFsp installer and install it.
Open `Services` and look for `VirtIO-FS Service`. Right click and go to its `Properties` page and change startup type to `Automatic`. While you are at it, start the service as well.

Done! By now your VM should have:
- Improved SPICE graphical console performance
- Automatic input grabbing/release in graphical console
- Clipboard sharing
- Filesystem sharing

Can you believe it was that easy? I'll have you say...

![image](https://github.com/Eastern-Dream/blog/blob/main/public/images/easy.jpg?raw=true)
