require 'vagrant'

module SparseImage
	module Command
		class Root < Vagrant.plugin("2", :command)
			def initialize(argv, env)
				super
				@main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
				@subcommands = Vagrant::Registry.new
				@subcommands.register(:mount) do
					Mount
				end
				@subcommands.register(:unmount) do
					Unmount
				end
				@subcommands.register(:destroy) do
					Destroy
				end
				@subcommands.register(:list) do
					List
				end
			end

			def execute
				if @main_args.include?("-h") || @main_args.include?("--help")
					# Print the help for all the sparseimage commands.
					return help
				end

				# If we reached this far then we must have a subcommand. If not,
				# then we also just print the help and exit.
				command_class = @subcommands.get(@sub_command.to_sym) if @sub_command
				return help if !command_class || !@sub_command
				@logger.debug("Invoking command class: #{command_class} #{@sub_args.inspect}")
				# Initialize and execute the command class
				command_class.new(@sub_args, @env).execute
			end

			# Prints the help out for this command
			def help
				opts = OptionParser.new do |opts|
				opts.banner = "Usage: vagrant sparseimage <command>"
				opts.separator ""
				opts.separator "Available subcommands:"

				# Add the available subcommands as separators in order to print them
				# out as well.
				keys = []
				@subcommands.each { |key, value| keys << key.to_s }

					keys.sort.each do |key|
						opts.separator "     #{key}"
					end

					opts.separator ""
					opts.separator "For help on any individual command run `vagrant sparseimage COMMAND -h`"
				end
				@env.ui.info(opts.help, :prefix => false)
			end
		end

		class List < Vagrant.plugin("2", :command)
			def execute
				@env.machine_names.each do |mname|
					machine = @env.machine(mname, :virtualbox)
					machine.ui.info("Listing sparse images for machine #{mname}")
					SparseImage::list(machine)
				end
			end
			def help
				@env.ui.info("Usage: vagrant sparseimage mount")
				@env.ui.info("\tMount all configured sparse images")
			end
		end



		class Mount < Vagrant.plugin("2", :command)
			def execute
				@env.machine_names.each do |mname|
					machine = @env.machine(mname, :virtualbox)
					machine.ui.info("Mounting sparse images for machine #{mname}")
					SparseImage::mount(machine)
				end
			end
			def help
				@env.ui.info("Usage: vagrant sparseimage mount")
				@env.ui.info("\tMount all configured sparse images")
			end
		end

		class Unmount < Vagrant.plugin("2", :command)
			def execute
				@env.machine_names.each do |mname|
					machine = @env.machine(mname, :virtualbox)
					machine.ui.info("Unmounting sparse images for machine #{mname}")
					SparseImage::unmount(machine)
				end
			end
			def help
				@env.ui.info("Usage: vagrant sparseimage unmount")
				@env.ui.info("\tUnmount all configured sparse images")
			end
		end

		class Destroy < Vagrant.plugin("2", :command)
			def execute
				@env.machine_names.each do |mname|
					machine = @env.machine(mname, :virtualbox)
					machine.ui.info("Destroying sparse images for machine #{mname}")
					SparseImage::destroy(machine)
				end
			end
			def help
				@env.ui.info("Usage: vagrant sparseimage destroy")
				@env.ui.info("\tDestroy all configured sparse images")
			end
		end
	end
end
