# vagrant-sparseimage

`vagrant-sparseimage` is a [Vagrant](http://vagrantup.com) plugin which automatically creates and mounts a sparseimage for the guest system to share. This allows alternative filesystems to be used between the host and the guest (eg. journaled, case sensitive).

The image can be browser from OSX Finder and is completely configurable. It can be unmounted automatically when the guest is halted, or left mounted for other uses. When the Vagrant guest is destroyed, the image can optionally be destroyed too.

## Dependencies

Only runs in OSX. Requires Vagrant v1.2+.

## Installation

See **building** below for building the gem.

Use `vagrant plugin` to install the gem in your Vagrant environment:

```bash
$ vagrant plugin install vagrant-sparseimage.gem
```

## Configuration

See `example-box/Vagrantfile`. Each vm has a sparseimage configuration object which can have an arbitrary number of images added to it.

The following config properties for `config.sparseimage` are compulsory:

* **volume_name**: the name that will be used to mount the volume and derive its filename
* **image_type**: `SPARSEIMAGE` or `SPARSEBUNDLE`
* **image_fs**: filesystem type: see below for list of supported formats
* **vm_mountpoint**: where to mount the image wihtin the guest
* **image_size**: size in MB. both image types will consume space lazily
* **image_folder**: the folder on the host to store the image file in

The following properties are optional:

* **auto_unmount**: whether to unmount the image from the host when the guest is stopped. Defaults to true.
* **mounted_folder**: the folder to mount the sparse bundles in. Defaults to being the same as the image_folder.

## Filesystems

* HFS+
* HFS+J (`JHFS+` in the config)
* HFSX
* JHFS+X
* MS-DOS
* UDF

## Building

If you installed vagrant using RubyGems, use:

```bash
$ bundle install
$ gem build vagrant-sparseimage.gemspec
```

If you installed Vagrant with a prebuilt package or installer, you need to use Vagrant's gem wrapper:
