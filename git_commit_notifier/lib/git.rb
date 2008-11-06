class Git
  def self.show(rev)
    `git show #{rev.strip} -w`
  end

  def self.rev_list(rev1, rev2)
    `git rev-list #{rev1} #{rev2}`.strip
  end

  def self.prefix
    `git config hooks.emailprefix`.strip
  end

  def self.mailing_list_address
    `git config hooks.mailinglist`.strip
  end
end
