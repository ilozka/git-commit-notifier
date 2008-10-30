class Git
  def self.show(rev)
    `git show #{rev} -w`
  end

  def self.log(rev1, rev2)
    `git log #{rev1}..#{rev2}`.strip
  end

  def self.prefix
    `git config hooks.emailprefix`.strip
  end

  def self.mailing_list_address
    `git config hooks.mailinglist`.strip
  end
end
