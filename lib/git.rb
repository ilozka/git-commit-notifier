class Git
  def self.show(rev)
    `git show #{rev.strip} -w`
  end

  def self.log(rev1, rev2)
    `git log #{rev1}..#{rev2}`.strip
  end

  def self.branch_commits(treeish)
    args = Git.branch_heads - [Git.branch_head(treeish)]
    args.map! {|tree| "^#{tree}"}
    args << treeish
    `git rev-list #{args.join(' ')}`.to_a.map{|commit| commit.chomp}
  end

  def self.branch_heads
    `git rev-parse --branches`.to_a.map{|head| head.chomp}
  end

  def self.branch_head(treeish)
    `git rev-parse #{treeish}`.strip
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
