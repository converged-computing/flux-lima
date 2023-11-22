# Flux Lima

I want to install Flux alongside [Lima](https://lima-vm.io) with tools for tracing (e.g., eBPF) so we can start to see what Flux is doing under the hood!

## Install

### Lima

To install I did:

```console
VERSION=$(curl -fsSL https://api.github.com/repos/lima-vm/lima/releases/latest | jq -r .tag_name)
wget "https://github.com/lima-vm/lima/releases/download/${VERSION}/lima-${VERSION:1}-$(uname -s)-$(uname -m).tar.gz"
tar -xzvf lima-0.18.0-Linux-x86_64.tar.gz
```

This extracts the bin and share in the present working directory to add to the path.

```bash
export PATH=$PWD/bin:$PATH
```

**Note** that you need [QEMU](https://itsfoss.com/qemu-ubuntu/) installed!
And note there are instructions for other platforms [here](https://lima-vm.io/docs/installation/)

### Virtio FSD

For having a filesystem that is available on provision we are going to use virtiofsd, but we can't use the default that ships with QEMU (it doesn't work). Instead we will install a rust variant. Note that you'll need the [rust version](https://gitlab.com/virtio-fs/virtiofsd) of virtiofsd for this to work (the old C version with QEMU did not work for me). 

```bash
# This is in the PWD
git clone https://gitlab.com/virtio-fs/virtiofsd 
cd virtiofsd 
sudo apt install libcap-ng-dev libseccomp-dev
```

Then build with cargo.

```bash
cargo build --release
```

Then I replaced it.

```bash
sudo mv /usr/lib/qemu/virtiofsd /usr/lib/qemu/virtiofsd-c
sudo mv virtiofsd/target/release/virtiofsd /usr/lib/qemu/virtiofsd
```

I also did:

```bash
sudo usermod -aG kvm $USER
```

You can then copy assets into `/tmp/lima` and the VMs that are using that mount will have access there on
startup.


## Recipes

The following recipes are included:

 - [flux-ebpf](flux-ebpf): Flux installed alongside eBPF for testing / fun.
 - [usernetes](usernetes): Flux installed and then running usernetes as a job.
