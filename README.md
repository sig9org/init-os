## Create qemu image

### Ubuntu 24.04 TLS

#### Step.1:Definition of Environment Variables

```sh
IMAGEDATE=20250313
```

#### Step.2:Download Images

Download with curl:

```sh
curl -L https://cloud-images.ubuntu.com/noble/${IMAGEDATE}/noble-server-cloudimg-amd64.img -o noble-server-cloudimg-amd64_extra-${IMAGEDATE}.qcow2
```

Download with axel:

```sh
axel https://cloud-images.ubuntu.com/noble/${IMAGEDATE}/noble-server-cloudimg-amd64.img -o noble-server-cloudimg-amd64_extra-${IMAGEDATE}.qcow2
```

#### Step.3:Image resizing

```sh
qemu-img resize noble-server-cloudimg-amd64_extra-${IMAGEDATE}.qcow2 +1.5G
LIBGUESTFS_TIMEOUT=7200 time virt-customize -v -x -a noble-server-cloudimg-amd64_extra-20251026.qcow2 \
  --run-command 'growpart /dev/sda 1' \
  --run-command 'resize2fs /dev/sda1' \
  --run-command "curl -Ls https://raw.githubusercontent.com/sig9org/init-os/master/init-qemu-ubuntu24.sh | bash -s"
```

#### Step.4:Customization

```sh
virt-customize -v -x -a noble-server-cloudimg-amd64_extra-${IMAGEDATE}.qcow2 --run-command "curl -Ls https://raw.githubusercontent.com/sig9org/init-os/master/init-qemu-ubuntu24.sh | bash -s"
```

## Install

### Base installation

```sh
curl -Ls https://raw.githubusercontent.com/sig9org/init-os/master/init-linux.sh | bash -s
```

### Full installation

```sh
curl -Ls https://raw.githubusercontent.com/sig9org/init-os/master/init-linux.sh | bash -s -- --extra
```
