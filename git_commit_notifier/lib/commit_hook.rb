require 'cgi'
require 'net/smtp'
require 'sha1'
require File.dirname(__FILE__) + '/diff_to_html'
require File.dirname(__FILE__) + '/emailer'
require File.dirname(__FILE__) + '/git'

class CommitHook

  def self.run(rev1, rev2, branch)
    config = YAML.parse_file(File.dirname(__FILE__) + '/../config/config.yml')

    recipient = config['email']['recipient_address'].value.empty? ? Git.mailing_list_address : config['email']['recipient_address'].value

    repo = config['email']['application_name'].value.empty? ? Git.prefix : config['email']['application_name'].value
    repo = 'scm' if repo.empty?
    prefix = "[#{repo}][#{branch}]"

    diff2html = DiffToHtml.new
    diff2html.diff_between_revisions rev1, rev2, repo, branch
    unless recipient.empty?
      diff2html.result.each do |result|
        emailer = Emailer.new recipient, result[:author_email], result[:author_name],
                       "#{prefix} #{result[:author_name]} - #{result[:message]}", result[:text_content], result[:html_content]
        emailer.send
      end
    end
  end

end
