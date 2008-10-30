require 'rubygems'
require 'mocha'
require 'test/unit'

require File.dirname(__FILE__) + '/../lib/commit_hook'
require File.dirname(__FILE__) + '/../lib/git'

class CommitHookTest < Test::Unit::TestCase

  def test_hook
    path = File.dirname(__FILE__) + '/fixtures/'
    Git.expects(:log).with(REVISIONS.first, REVISIONS.last).returns(read_file(path + 'git_log'))
    Git.expects(:mailing_list_address).returns('recipient@test.com')
    REVISIONS.each do |rev|
      Git.expects(:show).with(rev).returns(read_file(path + "git_show_#{rev}"))
    end
    emailer = mock('Emailer')
    Emailer.expects(:new).times(4).returns(emailer) # 4 commit, one email for each of them
    emailer.expects(:send).times(4)
    CommitHook.run REVISIONS.first, REVISIONS.last, 'master'
  end
end
