# Flux eBPF

This is for flux alongside eBPF.
 
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
