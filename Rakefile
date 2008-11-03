require 'rake'
require 'rake/testtask'
require 'rubygems'
require 'diff/lcs'

task :default => [:test]

task :test do |test|
  Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['git_commit_notifier/test/*.rb']
    t.verbose = true
  end
end

task :install do |install|
  puts "Full path to yor project repository (eg. /home/git/repositories/myproject.git):"
  project_path = STDIN.gets.strip

  hooks_dir = "#{project_path}/hooks"
  hooks_dir = "#{project_path}/.git/hooks" unless File.exist?(hooks_dir)
  raise 'hooks directory not found for the specified project - cannot continue' unless File.exist?(hooks_dir)
  hooks_dir += '/' unless hooks_dir[-1,-1] == '/'

  install_path = '/usr/local/share'

  execute_cmd "cp -r git_commit_notifier/ #{install_path}"
  execute_cmd "cp README.rdoc #{install_path}/git_commit_notifier"
  execute_cmd "cp LICENSE #{install_path}/git_commit_notifier"
  execute_cmd "mv #{hooks_dir}post-receive #{hooks_dir}post-receive.old.#{Time.now.to_i}" if File.exist?("#{hooks_dir}post-receive")
  execute_cmd "cp post-receive #{hooks_dir}"
  execute_cmd "cp commit_notifier_config.yml #{hooks_dir}"
  execute_cmd "chmod a+x #{hooks_dir}post-receive"

  Dir.chdir(project_path)
  config_file = "commit_notifier_config.yml"

  puts "Warning: no Git mailing list setting exists for your project. Please go to your project directory and set it with the git config hooks.mailinglist=you@yourdomain.com command or specify 'recipient_address' in the #{config_file} file else no emails can be sent out.\n\n"  if `git config hooks.mailinglist`.empty?
  puts "Warning: no Git email prefix setting exists for your project. Please go to your project directory and set it with the git config hooks.emailprefix=your_project_name or specify 'application_name' in the #{config_file} file\n\n" if `git config hooks.emailprefix`.empty?

  puts "Emails are sent by default via local sendmail. To change this, update #{config_file}"
  puts "Installation successful.\n\n"
end

def execute_cmd(cmd)
  `#{cmd}`
  raise 'error occurred - installation aborted' if $?.exitstatus != 0
end
