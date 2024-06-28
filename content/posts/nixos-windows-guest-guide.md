+++
title = 'Beginner guide to Wayland NixOS host and Windows 10/11 QEMU guest with filesystem and clipboard sharing through virt-manager'
date = 2024-06-28T16:59:21-04:00
draft = false
+++
## NixOS Host Configuration

[Follow the wiki](https://nixos.wiki/wiki/Virt-manager) to rebuild NixOS configuration to enable virt-manager, libvirtd, and a couple extra steps to make sure QEMU connection and network bridge is active. Additionally, for filesystem sharing you will need `virtiofsd` system package.

From here on out, I will assume you are familiar with virt-manager and already have a basic Windows VM with networking active.

## Installing Windows Guest Tools and Drivers

The simplest way is to start download from within the VM via web browser. We need three different tools and drivers installation for the Windows guest:
- [VirtIO Windows Tools](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/). Navigate to the directory of the latest version and choose the wizard installer `virtio-win-gt-x64.msi`.
- [SPICE Windows Guest Tools](https://www.spice-space.org/download.html). The download link can be found under the Windows binaries section.
- [Windows File System Proxy (WinFsp)](https://winfsp.dev/). This is a Windows FUSE driver and is needed for virtiofs guest driver to work.

Run the installers one-by-one, I don't think it matters what order you run them in.

Before you shutdown or reboot the VM, open `Services` and look for `VirtIO-FS Service`. Right click and go to its `Properties` page and change startup type to `Automatic (Delayed Start)`.

## Filesystem Sharing Configuration

Libvirtd don't know where `virtiofsd` is on NixOS. So we gotta find it and specify the binary path for it. You will specify the correct path later in virt-manager.
```
$ which virtiofsd
/run/current-system/sw/bin/virtiofsd
```

Back to virt-manager, there are a couple things to do:
- Make sure `Enable shared memory` is enabled in `Memory` section of the VM hardware config.
- Make sure XML editing is enabled under Edit > Preferences > General.
- Add hardware `Filesystem`. In the XML tab, add this line to the inner node `<binary path="/run/current-system/sw/bin/virtiofsd"/>`. Finish configuring source and target path.
- Do not enable readonly mount, it is not supported by virtiofs.

Done! The next time you boot up the VM you should have:
- Improved graphical console performance
- Automatic input grabbing/release in graphical console
- Clipboard sharing
- Filesystem sharing

It's that easy (hopefully). Happy virtualizing.

If you see any editorial error please open an issue.