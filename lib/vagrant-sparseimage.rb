begin
	FileUtils
rescue NameError
	begin
		require 'FileUtils'
	rescue LoadError
		require 'fileutils'
	end
end

require 'pp'
require 'optparse'

begin
	require 'vagrant'
rescue LoadError
	raise 'The Vagrant SparseImage plugin must be run within Vagrant.'
end
require Vagrant.source_root.join("plugins/commands/up/start_mixins")

require File.expand_path("../vagrant-sparseimage/command", __FILE__)
require File.expand_path("../vagrant-sparseimage/hdiutil", __FILE__)

module SparseImage

	class << self
		# Run the command, wait for exit and return the Process object.
		def run(cmd)
			pid = Process.fork { exec(cmd) }
			Process.waitpid(pid)
			return $?
		end

		def list(vm)
			vm.config.sparseimage.to_hash[:images].each do |opts|
				pp opts.to_hash
			end
		end

		def mount(vm)
			# mount each configured sparse image
			vm.config.sparseimage.to_hash[:images].each do |opts|
				# Derive the full image filename and volume mount path (for the host)
				full_image_filename = "#{opts.image_folder}/#{opts.volume_name}.#{opts.image_type}".downcase

				# Does the image need to be created?
				if File.exists? full_image_filename
					vm.ui.info "Found sparse disk image: #{full_image_filename}"
				else
					# Create the directory if it does not exist
					FileUtils.mkdir_p opts.image_folder if not File.exists? opts.image_folder

					# hdiutil is finnicky with image type
					type = opts.image_type == 'SPARSEIMAGE' ? 'SPARSE' : opts.image_type
					vm.ui.info "Creating #{opts.image_size}MB sparse disk image: #{full_image_filename}"
					# TODO - move this into SparseImage::HDIUTIL::create
					# TODO - raise an exception if create fails
					SparseImage::HDIUTIL::create(vm, type, opts.image_size, opts.image_fs, opts.volume_name, full_image_filename)
					vm.ui.info("Created disk image in the host: #{full_image_filename}")
				end

				# Mount the image in the host
				vm.ui.info("Mounting disk image in the host: #{full_image_filename} at #{opts.mounted_name}")
				SparseImage::HDIUTIL::mount(vm, opts.mounted_name, full_image_filename)

				# Remove nonsense hidden files
				errors = SparseImage::HDIUTIL::remove_OSX_fuzz(vm, opts.mounted_name)
				if errors.length > 0
					errors.each do |error| vm.ui.info(error) end
				end

				vm.config.vm.synced_folders[opts.volume_name] = {
					:hostpath => opts.mounted_name,
					:guestpath => opts.vm_mountpoint,
					:nfs => true,
				}
				vm.ui.info("Mounted disk image in the guest: #{full_image_filename} at #{opts.vm_mountpoint}")
			end
		end

		def unmount(vm)
			# Unmount each configured sparse image
			vm.config.sparseimage.to_hash[:images].each do |opts|
				if opts.auto_unmount
					SparseImage::HDIUTIL::unmount(vm, opts.mounted_name)
				end
			end
		end

		def destroy(vm)
			# Prompt to destroy each configured sparse image
			vm.config.sparseimage.to_hash[:images].each do |opts|
				cancel = false
				full_image_filename = "#{opts.image_folder}/#{opts.volume_name}.#{opts.image_type}".downcase
				# Confirm destruction of the sparse image
				while cancel == false
					choice = vm.ui.ask("Do you want to delete the sparse image at #{full_image_filename}? [Y/N] ")
					if choice.upcase == 'Y'
						choice = vm.ui.ask("Confirm the name of the volume to destroy [#{ opts.volume_name}] ")
						if choice == opts.volume_name
							# TODO - Test first whether it's mounted before trying to unmount
							#SparseImage::HDIUTIL::unmount(vm, opts.mounted_name)
							SparseImage::HDIUTIL::destroy(vm, full_image_filename)
							cancel = true
						else
							vm.ui.error("name does not match.")
						end
					else
						cancel = true
						vm.ui.error("Image '#{opts.volume_name}' was not destroyed.")
					end
				end
			end
		end
	end

	class ImageConfig
		# Configuration for a single sparse image
		# Not exposed to vagrant.

		attr_accessor :vm_mountpoint, :image_size, :image_fs, :image_type, :volume_name, :image_folder,
						:auto_unmount, :mounted_name
		
		@@required = [
			:volume_name,
			:image_type,
			:image_fs,
			:vm_mountpoint,
			:image_size,
			:image_folder
		]

		@@valid_image_types = ["SPARSEIMAGE", "SPARSEBUNDLE"]

		def validate
			errors = []
			# Check for the required config keys
			@@required.each do |key|
				if not to_hash[key] or (to_hash[key].is_a? String  and to_hash[key].length == 0)
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
			if @mounted_name.nil?
				@mounted_name = "./#{@volume_name}"
			end
		end

		def to_hash
			{	:vm_mountpoint  => @vm_mountpoint,
				:image_size     => @image_size,
				:image_fs       => @image_fs,
				:image_type     => @image_type,
				:volume_name	=> @volume_name,
				:auto_unmount	=> @auto_unmount,
				:image_folder	=> @image_folder,
				:mounted_name	=> @mounted_name
			}
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
			SparseImage::mount(vm)
			@app.call(env)
		end
	end

	class Unmount
		# Startup hook
		# Unmount the shared drive from the host machine
		# Fails silently if the drive was not mounted
		def initialize(app, env)
			@app = app
			@env = env
		end
		def call(env)
			vm = env[:machine]
			SparseImage::mount(vm)
			@app.call(env)
		end
	end

	class Unmount
		# Shutdown hook
		# Unmount the shared drive from the host machine
		# Fails silently if the drive was not mounted
		def initialize(app, env)
			@app = app
			@env = env
		end
		def call(env)
			vm = env[:machine]
			SparseImage::unmount(vm)
			@app.call(env)
		end
	end

	class Destroy
		# Shutdown hook
		# Unmount the shared drive from the host machine and delete it.
		# Confirm with the user first.
		def initialize(app, env)
			@app = app
			@env = env
		end
		def call(env)
			vm = env[:machine]
			SparseImage::destroy(vm)
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

		def finalize!
			@@images.each do |image|
				image.finalize!
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
		description "A vagrant plugin to managed shared sparse images."

		config(:sparseimage) do
			# Yield a config object to the vagrant file.
			# Vagrant will handle persisting the state of this object for each VM.
			Config
		end

		command("sparseimage") do
			Command::Root
		end

		action_hook(self::ALL_ACTIONS) do |hook|
			hook.after(VagrantPlugins::ProviderVirtualBox::Action::ForwardPorts, Mount)
			hook.after(Vagrant::Action::Builtin::GracefulHalt, Unmount)
			hook.after(Vagrant::Action::Builtin::DestroyConfirm, Destroy)
		end
	end
end
