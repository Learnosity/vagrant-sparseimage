module VagrantSparseimage
    class Config < Vagrant::Config::Base

        module Attributes
            attr_accessor :enabled, :volume_name, :vm_mountpoint,
                :image_filename, :image_size, :image_fs, :image_bundle,
                :nfs_options, :auto_unmount
        end

        class << self
            include Attributes

            def enabled; 		@enabled.nil? 		? false	: @enabled end
            def auto_unmount; 	@auto_unmount.nil? 	? true 	: @auto_unmount end
            def image_bundle; 	@image_bundle.nil? 	? false	: @image_bundle end

            def volume_name
                return nil if !@volume_name || @volume_name == :auto
                @volume_name
            end

            def vm_mountpoint
                return nil if !@vm_mountpoint || @vm_mountpoint == :auto
                @vm_mountpoint
            end

            def image_filename
                return nil if !@image_filename || @image_filename == :auto
                @image_filename
            end

            def image_size
                return nil if !@image_size || @image_size == :auto
                @image_size
            end

            def image_fs
                return nil if !@image_fs || @image_fs == :auto
                @image_fs
            end

            def nfs_options
                return nil if !@nfs_options || @nfs_options == :auto
                @nfs_options
            end
        end

        include Attributes

        def enabled; 		@enabled.nil? 		? self.class.enabled 		: @enabled end
        def auto_unmount; 	@auto_unmount.nil? 	? self.class.auto_unmount 	: @auto_unmount end
        def image_bundle; 	@image_bundle.nil? 	? self.class.image_bundle 	: @image_bundle end

        def volume_name
            return self.class.volume_name if !@volume_name | @volume_name == :auto
            @volume_name
        end

        def vm_mountpoint
            return self.class.vm_mountpoint if !@vm_mountpoint | @vm_mountpoint == :auto
            @vm_mountpoint
        end

        def image_filename
            return self.class.image_filename if !@image_filename | @image_filename == :auto
            @image_filename
        end

        def image_size
            return self.class.image_size if !@image_size | @image_size == :auto
            @image_size
        end

        def image_fs
            return self.class.image_fs if !@image_fs | @image_fs == :auto
            @image_fs
        end

        def nfs_options
            return self.class.nfs_options if !@nfs_options | @nfs_options == :auto
            @nfs_options
        end

        def to_hash
            {
                :enabled 			=> enabled,
                :volume_name 		=> volume_name,
                :vm_mountpoint		=> vm_mountpoint,
                :image_filename		=> image_filename,
                :image_size			=> image_size,
                :image_fs			=> image_fs,
                :nfs_options		=> nfs_options,
                :image_bundle		=> image_bundle,
                :auto_unmount		=> auto_unmount
            }
        end
    end
end

