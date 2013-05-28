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

		def validate
			errors = []
			# Check for the required config keys
			@@required.each do |key|
				if not to_hash[key] or (to_hash[key].is_a? String  and to_hash[key].length == 0)
					puts to_hash
					errors.push "#{key} must be present."
				end
			end

			# Validate image type
			if not @@valid_image_types.include?(@image_type)
				errors.push "image_type: invalid value: only supports #{@@valid_image_types.join(',')}"
			end

			# Size must be an int
			if @image_size and not @image_size.is_a? Fixnum
				errors.push "image_size: Must be a number."
			end
			{ "vagrant-sparseimage" => errors }
		end

		def finalize!
			if @auto_unmount.nil?
				@auto_unmount = true
			end
		end

		def to_hash
			{	:vm_mountpoint  => @vm_mountpoint,
				:image_size     => @image_size,
				:image_fs       => @image_fs,
				:image_type     => @image_type,
				:volume_name	=> @volume_name,
				:auto_unmount	=> @auto_unmount,
				:image_folder	=> @image_folder }
		end
	end

	class Mount
		# Mount sparse images on the host machine and add them to the config for the guest
		# Create the sparse image files if necessary.

		def initialize(app, env)
			@app = app
			@env = env
		end

		def call(env)
			vm = env[:machine]
			vm.config.sparseimage.to_hash[:images].each do |opts|
				# Derive the full image filename and volume mount path (for the host)
				full_image_filename = "#{opts.image_folder}/#{opts.volume_name}.#{opts.image_type}".downcase
				full_volume_path = "#{opts.image_folder}/#{opts.volume_name}".downcase

				# Does the image need to be created?
				if File.exists? full_image_filename
					vm.ui.info "Found sparse disk image: #{full_image_filename}"
				else
					# Create the directory if it does not exist
					FileUtils.mkdir_p opts.image_folder if not File.exists? opts.image_folder

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
					full_volume_path = "#{options.image_folder}/#{options.volume_name}".downcase
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

				full_image_filename = "#{options.image_folder}/#{options.volume_name}.#{options.image_type}".downcase
				full_volume_path = "#{options.image_folder}/#{options.volume_name}".downcase

				# First unmount the volume
				vm.ui.info("Unmounting disk image from host: #{full_volume_path}")
				system("hdiutil detach -quiet '#{full_volume_path}'")

				# Confirm destruction of the sparse image
				choice = vm.ui.ask("Do you want to delete the sparse image at #{full_image_filename}? [Y/N] ")
				if choice.upcase == 'Y'
					vm.ui.info("Destroying disk image at #{full_image_filename}")
					if File.exists?(full_image_filename)
						if File.directory?(full_image_filename)
							FileUtils.rm_rf(full_image_filename)
						else
							File.delete(full_image_filename)
						end
					end
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
				image_errors = image.validate()
				if image_errors.length > 0
					image_errors.each do |key, value|
						errors[key] ||= []
						errors[key] += value
					end
				end
			end
			errors
		end

		def to_hash
			return { :images => @@images }
		end
	end

	class Plugin < Vagrant.plugin("2")
		name "vagrant sparse image support"
		description "A vagrant plugin to create a mount sparse images into the guest VM"

		config(:sparseimage) do
			# Yield a config object to the vagrant file.
			# Vagrant will handle persisting the state of this object for each VM.
			Config
		end

		action_hook(self::ALL_ACTIONS) do |hook|
			hook.after(VagrantPlugins::ProviderVirtualBox::Action::ForwardPorts, Mount)
			hook.after(Vagrant::Action::Builtin::GracefulHalt, Unmount)
			hook.after(Vagrant::Action::Builtin::DestroyConfirm, Destroy)
		end
	end
end
