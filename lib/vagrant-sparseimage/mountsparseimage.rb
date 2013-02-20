module VagrantSparseimage
	class MountSparseImage
		def initialize(app, env)
			@app = app
			@env = env
		end

		def call(env)
			@env 	= env
			vm		= env[:vm]
			options	= vm.config.sparseimage.to_hash

			if options[:enabled] 
				volume_name 	= options[:volume_name]
				vm_mountpoint	= options[:vm_mountpoint]
				image_filename	= options[:image_filename]
				image_size		= options[:image_size]
				image_fs		= options[:image_fs]

				# Set the defaults if the properties aren't set
				if !volume_name || volume_name.empty? || volume_name == :auto
					volume_name = File.basename(env[:root_path]) + "-image"
				end

				if !vm_mountpoint || vm_mountpoint.empty? || vm_mountpoint == :auto
					vm_mountpoint = "/" + File.basename(env[:root_path])
				end

				if !image_filename || image_filename.empty? || image_filename == :auto
					image_filename = ".#{vm.config.vm.name}"
				end

				if !image_fs || image_fs.empty? || image_fs == :auto
					image_fs = "JHFS+X"
				end

				if File.exists?(image_filename + ".sparseimage")
					vm.ui.info "Found sparse disk image: #{image_filename}.sparseimage"
				else
					if !image_size || image_size == :auto
						image_size = env[:ui].ask("How large do you want the image to be in GB? ").to_i
					end

					vm.ui.info "Creating #{image_size}GB sparse disk image with " +
						"name #{image_filename}.sparseimage ..."

					system("hdiutil create -type SPARSE "+
						   "-size #{image_size}g " +
						   "-fs #{image_fs} " +
						   "-volname #{volume_name} " +
						   "#{image_filename}"
						  );
						  vm.ui.info "... done!"
				end

				vm.ui.info "Mounting disk image #{image_filename}.sparseimage ..."
				system("hdiutil attach -mountroot . #{image_filename}.sparseimage")
				vm.ui.info "... done!"

				vm.config.vm.share_folder(
					volume_name, vm_mountpoint, "./#{volume_name}", :nfs => ["ac","acregmin=1"]
				)
			end

			@app.call(env)
		end
	end
end

