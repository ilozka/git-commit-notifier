class Git
  def self.show(rev)
    `git show #{rev.strip} -w`
  end

  def self.log(rev1, rev2)
    `git log #{rev1}..#{rev2}`.strip
  end

  def self.repo_name
    git_prefix = `git config hooks.emailprefix`.strip
    return git_prefix unless git_prefix.empty?
    dir_name = `pwd`.chomp.split("/").last.gsub(/\.git$/, '')
    return "#{dir_name}"
  end

  def self.mailing_list_address
    `git config hooks.mailinglist`.strip
  end
end
