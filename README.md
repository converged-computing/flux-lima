# Flux Lima

I want to install Flux alongside [Lima](https://lima-vm.io) with tools for tracing (e.g., eBPF) so we can start to see
what Flux is doing under the hood!

## Install

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

## Usage

```bash
limactl start --network=lima:user-v2 --name=flux-lima ./flux-lima.yaml
```

It says it doesn't reach running status, but I don't see any errors in the logs, and the shell works:

```bash
limactl shell flux-lima
export PATH=/opt/conda/bin:$PATH
```

And then try flux!

```bash
export PATH=/opt/conda/bin:$PATH
$ flux start --test-size=4
$ flux run hostname
lima-flux-lima
```

Woop!

## Clean Up

You can stop:

```bash
limactl stop flux-lima
```

or just nuke it!

```bash
limactl delete flux-lima
```
