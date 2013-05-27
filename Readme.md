# vagrant-sparseimage

`vagrant-sparseimage` is a [Vagrant](http://vagrantup.com) plugin which automatically creates and mounts a sparseimage for the guest system to share. This allows alternative filesystems to be used between the host and the guest (eg. journaled, case sensitive).

The image can be browser from OSX Finder and is completely configurable. It can be unmounted automatically when the guest is halted, or left mounted for other uses. When the Vagrant guest is destroyed, the image can optionally be destroyed too.

## Dependencies

Only runs in OSX. Requires vagrant 0.9.4 or later (including 1.0). Does not currently support Vagrant 1.1+ - the plugin API changed.

## Installation

Since Vagrant v1.0.0, the preferred installation method is using prebuilt packages or installers.

If you installed vagrant that way, you need to use vagrant's gem wrapper:

```bash
$ vagrant gem install vagrant-sparseimage
```

If you installed vagrant using RubyGems, use:

```bash
$ gem install vagrant-sparseimage
```

## Configuration

See `example-box/Vagrantfile`. Each vm has a sparseimage configuration object which can have an arbitrary number of images added to it.

The following config properties for `config.sparseimage` are compulsory:

* **volume_name**: the name that will be used to mount the volume and derive its filename
* **image_type**: `SPARSEIMAGE` or `SPARSEBUNDLE`
* **image_fs**: `JHFS+` or ??
* **vm_mountpoint**: where to mount the image wihtin the guest
* **image_size**: size in MB. both image types will consume space lazily
* **image_folder**: the folder on the host to store the image file in

The following properties are optional:

* **auto_unmount**: whether to unmount the image from the host when the guest is stopped. Defaults to true.

## Building

If you installed vagrant using RubyGems, use:

```bash
$ bundle install
$ gem build vagrant-sparseimage.gemspec
```

If you installed Vagrant with a prebuilt package or installer, you need to use Vagrant's gem wrapper:

```bash
$ bundle install
$ vagrant gem build vagrant-sparseimage.gemspec
```
