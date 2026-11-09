# Mini Container — Building Containers Without Docker

A hands-on Linux containerization project built using native Linux kernel features, without Docker, Podman, or an existing container runtime.

The goal is to understand how container isolation works at the operating system level.

## Features

- Linux Namespaces: PID, UTS, Mount, Network and User
- Debian 13 (Trixie) root filesystem
- Cgroups v2 for CPU and memory limits
- Virtual Ethernet (veth) networking
- NAT using nftables
- Automatic network setup and cleanup
- Separate rootful and rootless launchers
- Independent Linux Capabilities and Seccomp experiments

## Architecture

**Rootful launcher (`start.sh`)**

Kali Linux → systemd scope (Cgroups v2) → Network Namespace → PID/UTS/Mount Namespaces → Debian RootFS → Bash

Configured limits:
- Memory: 256 MiB
- CPU quota: 100% (equivalent to one logical CPU)
- Container IP: 10.202.88.2

**Rootless launcher (`start-rootless.sh`)**

Normal Linux user → User Namespace (UID mapping) → PID/UTS/Mount Namespaces → Debian RootFS → Bash

Rootless mode does not currently include automated networking or Cgroups resource limits.

## Requirements

- Linux with the necessary namespace and Cgroups v2 features
- Bash, util-linux and iproute2
- systemd and systemd-run for rootful mode
- nftables for rootful networking
- Debian debootstrap
- libseccomp-dev and GCC for the independent Seccomp experiment

Tested in a Kali Linux laboratory environment.

## Prepare the Debian RootFS

```bash
sudo apt update
sudo apt install -y debootstrap
mkdir -p rootfs

sudo debootstrap --variant=minbase stable \
  rootfs https://deb.debian.org/debian
```

The laboratory used Debian 13 (Trixie). For reproducible results, pin a specific Debian release rather than relying on the changing `stable` alias.

For the rootless experiment, a separate filesystem was prepared:

```bash
sudo cp -a rootfs rootfs-rootless
```

## Run the Rootful Container

```bash
sudo ./start.sh
```

This launches the educational container with namespace isolation, veth networking, NAT and resource limits.

Exit the container using:

```bash
exit
```

The launcher attempts to clean up its network resources on normal exit.

## Run the Rootless Container

```bash
./start-rootless.sh
```

Do not use `sudo`.

This launcher maps the container's UID 0 to the invoking user's host UID.

Check the mapping inside the container:

```bash
cat /proc/self/uid_map
```

## Seccomp Experiment

Compile the standalone example:

```bash
gcc -Wall -Wextra seccomp-test.c \
  -o seccomp-test -lseccomp

./seccomp-test
```

The example applies a Seccomp filter denying the `getppid()` system call with `EPERM`.

The Seccomp filter is not integrated into the container launchers.

## Security Limitations

**This project is for education and trusted laboratory workloads only. It is not a secure production container runtime.**

- The rootful launcher uses host root privileges.
- Capability reduction in the main launcher has not been fully verified and must not be assumed effective.
- The rootless launcher has a separate, limited feature set.
- Seccomp was demonstrated independently, not enforced by the launchers.
- Root filesystem isolation is based on `chroot`, not a complete hardened filesystem architecture.
- Device access, filesystem mounts, networking, and lifecycle management require further hardening.
- Full OCI image and runtime compatibility is not implemented.

## Project Status

Educational prototype with working rootful and rootless launchers. Further security hardening and integration are future work.

## Purpose

This project demonstrates the Linux primitives underlying container technology through practical experiments, including successful isolation tests, resource-control observations, and documented implementation limitations.
