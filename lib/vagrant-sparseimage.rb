require 'vagrant'

require 'vagrant-sparseimage/config'
require 'vagrant-sparseimage/mountsparseimage'
require 'vagrant-sparseimage/unmountsparseimage'
require 'vagrant-sparseimage/destroysparseimage'

Vagrant.config_keys.register(:sparseimage) { VagrantSparseimage::Config }

Vagrant.actions[:start].insert_after(Vagrant::Action::VM::ForwardPorts, VagrantSparseimage::MountSparseImage)
Vagrant.actions[:halt].insert_after(Vagrant::Action::VM::Halt, VagrantSparseimage::UnmountSparseImage)
Vagrant.actions[:destroy].insert_after(Vagrant::Action::VM::DestroyUnusedNetworkInterfaces, VagrantSparseimage::DestroySparseImage)
