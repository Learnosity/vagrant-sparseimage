begin
	FileUtils
rescue NameError
	require 'FileUtils'
end
require 'pp'

begin
	require 'vagrant'
rescue LoadError
	raise 'The Vagrant SparseImage plugin must be run within Vagrant.'
end

module SparseImage
	VERSION = "0.1.2"

	class ImageConfig
		# Configuration for a single sparse image
		# Not exposed to vagrant.

		attr_accessor :vm_mountpoint, :image_size, :image_fs, :image_type, :volume_name, :image_folder, :auto_unmount
		
		@@required = [
			:volume_name,
			:image_type,
			:image_fs,
			:vm_mountpoint,
			:image_size,
			:image_folder ]

		@@valid_image_types = ["SPARSEIMAGE", "SPARSEBUNDLE"]

		def validate(machine)
			errors = {}
			# Check for the required config keys
			@@required.each do |key|
				if not to_hash[key] or (to_hash[key].is_a? String  and to_hash[key].length == 0)
					errors[key] = ["Must be present."]
				end
			end

			# Validate image type
			if not @@valid_image_types.include?(@image_type)
				errors[key] = ["Invalid value: only supports #{@@valid_image_types.join(',')}"]
			end

			# Size must be an int
			if @image_size and not @image_size.is_a? Fixnum
				errors[key] = ["Must be a number."]
			end
			{}
			#errors
		end

		def finalize!
			if @auto_unmount.nil?
				@auto_unmount = true
			end
		end

		def to_hash
			{	:vm_mountpoint   => @vm_mountpoint,
				:image_filename  => @image_filename,
				:image_size      => @image_size,
				:image_fs        => @image_fs,
				:image_type      => @image_type,
				:image_folder	 => @image_folder }
		end
	end

	class Mount
		def initialize(app, env)
			@app = app
			@env = env
		end

		def call(env)
			vm = env[:machine]
			vm.config.sparseimage.to_hash[:images].each do |opts|
				# Derive the full image filename and volume mount path (for the host)
				full_image_filename = "#{opts.image_folder}/#{opts.volume_name}.#{opts.image_type}"
				full_volume_path = "#{opts.image_folder}/#{opts.volume_name}"

				# Does the image need to be created?
				if File.exists? full_image_filename
					vm.ui.info "Found sparse disk image: #{full_image_filename}"
				else
					# Create the directory if it does not exist
					FileUtil.mkdir_p opts.image_folder if not File.exists? opts.image_folder

					# hdiutil is finnicky with image type
					type = opts.image_type == 'SPARSEIMAGE' ? 'SPARSE' : opts.image_type
					vm.ui.info "Creating #{opts.image_size}MB sparse disk image: #{full_image_filename}"
					system("hdiutil create -type '#{type}' " +
						   "-size '#{opts.image_size}m' " +
						   "-fs '#{opts.image_fs}' " +
						   "-volname '#{opts.volume_name}' " +
						   "'#{full_image_filename}'")
				end

				# Mount the image in the host
				vm.ui.info("Mounting disk image in the host: #{full_image_filename}")
				system("hdiutil attach -mountroot '#{opts.image_folder}' '#{full_image_filename}'")

				env[:machine].config.vm.synced_folders[opts.volume_name] = {
					:hostpath => full_volume_path,
					:guestpath => opts.vm_mountpoint,
					:nfs => true
				}
			end

			@app.call(env)
		end
	end

	class Unmount
		# Unmount the shared drive from the host machine
		# Fails silently if the drive was not mounted

		def initialize(app, env)
			@app = app
			@env = env
		end
		def call(env)
			vm = env[:machine]
			vm.config.sparseimage.to_hash[:images].each do |options|
				if options.auto_unmount
					full_volume_path = "#{options.image_folder}/#{options.volume_name}"
					vm.ui.info("Unmounting disk image from host: #{full_volume_path}")
					system("hdiutil detach -quiet '#{full_volume_path}'")
				end
			end
			@app.call(env)
		end
	end

	class Destroy
		# Unmount the shared drive from the host machine and delete it.
		# Confirm with the user first.

		def initialize(app, env)
			@app = app
			@env = env
		end
		def call(env)
			vm = env[:machine]
			vm.config.sparseimage.to_hash[:images].each do |options|

				full_image_filename = "#{options.image_folder}/#{options.volume_name}.#{options.image_type}"
				full_volume_path = "#{options.image_folder}/#{options.volume_name}"

				# First unmount the volume
				vm.ui.info("Unmounting disk image from host: #{full_volume_path}")
				system("hdiutil detach -quiet '#{full_volume_path}'")

				# Confirm destruction of the sparse image
				choice = vm.ui.ask("Do you want to delete the sparse image at #{full_image_filename}? [Y/N] ")
				if choice.upcase == 'Y'
					vm.ui.info("Destroying disk image at #{full_image_filename}")
					File.delete(full_image_filename)
				end
			end

			@app.call(env)
		end
	end

	class Config < Vagrant.plugin("2", :config)
		# Singleton
		@@images = []
		class << self
			attr_accessor :images
		end

		def add_image
			if not block_given?
				raise 'add_image must be given a block.'
			end
			image = ImageConfig.new
			yield image
			@@images.push(image)
		end


		def finalise!
			@@images.each do |image|
				image.finalise!
			end
		end

		def validate(machine)
			errors = {}

			# Validate each of the image configs in turn
			@@images.each_with_index do |image, i|
				image_errors = image.validate(machine)
				if image_errors.length > 0
					errors[i] = image_errors
				end
			end

			errors
		end

		def to_hash
			# TODO - can it be done without this?
			return { :images => @@images }
		end
	end

	class Plugin < Vagrant.plugin("2")
		# The actual vagrant plugin
		# This is here for two reasons:
		#	* to yield a Config object to the Vagrantfile
		#	* to 
		name "vagrant sparse image support"
		description "A vagrant plugin to create a mount sparse images into the guest VM"

		config(:sparseimage) do
			# Yield a config object to the vagrant file.
			# Vagrant should handle persisting the state of this object.
			#Config
			Config
		end

		action_hook(self::ALL_ACTIONS) do |hook|
			#hook.after(VagrantPlugins::ProviderVirtualBox::Action::Boot, Mount)
			hook.after(VagrantPlugins::ProviderVirtualBox::Action::ForwardPorts, Mount)
			hook.after(Vagrant::Action::Builtin::GracefulHalt, Unmount)
			hook.after(Vagrant::Action::Builtin::DestroyConfirm, Destroy)

			#hook.after(VagrantPlugins::ProviderVirtualBox::Action::ForcedHalt, Unmount)
			# TODO - confirm that Destroy is not called when confirm is declined
		end
	end
end
