module SparseImage
	module HDIUTIL
		class << self
			# Try to mount the image. If it fails, return a warning (as a string)
			def mount(vm, mount_in, image_path)
				if not SparseImage::run("hdiutil attach -mountpoint '#{mount_in}' '#{image_path}'").success?
					vm.ui.error("WARNING: Failed to mount #{image_path} at #{mount_in}")
				end
			end

			# Unmount the image
			def unmount(vm, mounted_in)
				vm.ui.info("Unmounting disk image from host: #{mounted_in}")
				if not SparseImage::run("hdiutil detach -quiet '#{mounted_in}'").success?
					vm.ui.error("WARNING: Failed to unmount #{mounted_in}. It may not have been mounted.")
				end
			end

			# Delete the image
			def destroy(vm, image_filename)
				vm.ui.info("Destroying disk image at #{image_filename}")
				if File.exists?(image_filename)
					if File.directory?(image_filename)
						FileUtils.rm_rf(image_filename)
					else
						File.delete(image_filename)
					end
				end
			end

			# Create a sparseimage
			def create(vm, type, image_size, image_fs, volume_name, full_image_filename)
				if not SparseImage::run("hdiutil create -type '#{type}' " +
					   "-size '#{image_size}m' " +
					   "-fs '#{image_fs}' " +
					   "-volname '#{volume_name}' " +
					   "'#{full_image_filename}'")
					vm.ui.error("ERROR: Failed to create sparseimage #{full_image_filename}")
				end
			end

			# Remove all the nonsense that comes with a mounted sparse image in OSX
			def remove_OSX_fuzz(vm, mounted_dir)
				# Append trailing slash if it's missing from the mounted dir
				mounted_dir = "#{mounted_dir}/" unless mounted_dir[-1] == '/'
				errors = []
				['.fseventsd', '.Spotlight-V*', '.Trashes'].each do |rubbish|
					path = "#{mounted_dir}#{rubbish}"
					if File.exists?(path)
						p = SparseImage::run("rm -rf #{path}")
						vm.ui.info("Removing #{path}")
						if not p.success?
							vm.ui.error("Failed to remove #{rubbish} from #{mounted_dir}. It may not have existed.")
						end
					end
				end
				return errors
			end
		end
	end
end
