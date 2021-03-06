class Chef
  class Recipe
    # methods to help install git-hooks, which allows more than one git-hook
    # only class methods, not instance methods, as no objects are being created
    class GitHooks
      include Chef::Mixin::ShellOut

      def initialize(user)
        @user = user
      end

      def install(search_dir)
        return unless ::Dir.exist?(search_dir)

        find_git_files(search_dir).each do |git_file|
          check_and_install_git_hooks(git_file)
        end
      end

      private

      def find_git_files(search_dir)
        cmd = shell_out!("find #{search_dir} -name .git")
        cmd.stdout.split("\n")
      end

      def check_and_install_git_hooks(git_file)
        ::Dir.chdir(::File.dirname(git_file)) do
          git_dir = find_git_dir(git_file)

          unless ::Dir.exist?(::File.join(git_dir, 'hooks.old'))
            copy_recovered_hooks git_file, git_dir
            install_git_hooks git_file
          end
        end
      end

      def install_git_hooks(git_file)
        repo_dir = ::File.dirname(git_file)
        Chef::Log.info("Installing git-hooks into: #{repo_dir}")
        ::Dir.chdir(repo_dir) do
          shell_out!('git hooks install', user: @user)
        end
      end

      def find_git_dir(git_file)
        cmd = shell_out!("git rev-parse --resolve-git-dir '#{git_file}'")
        cmd.stdout.strip
      end

      def copy_recovered_hooks(git_file, git_dir)
        get_unapplied_hook_files(git_dir).each do |hook|
          hook_dir = ::File.join(::File.dirname(git_file), 'githooks', ::File.basename(hook))
          FileUtils.mkdir_p(hook_dir)
          FileUtils.chown_R(@user, nil, hook_dir)
          dest = ::File.join(hook_dir, 'recovered-hook')

          Chef::Log.info("Copying hooks from #{hook} to #{dest}")
          FileUtils.cp(hook, dest)
          FileUtils.chown(@user, nil, dest)
        end
      end

      def get_unapplied_hook_files(git_dir)
        potential_hook_files = ::Dir.glob(::File.join(git_dir, 'hooks', '*'))

        potential_hook_files.reject do |hook_file|
          hook_file[/.sample$/] &&
            !::File.read(hook_file).match(/git-hooks/)
        end
      end
    end
  end
end
