require 'rubygems'
require 'cgi'
require 'net/smtp'
require 'sha1'

require 'diff_to_html'
require 'emailer'
require 'git'

class CommitHook

  def self.run(rev1, rev2, ref_name)

    project_path = Dir.getwd

    recipient = Git.mailing_list_address
    prefix = Git.prefix
    prefix = 'git' if prefix.empty?
    repo = Git.reponame
    subject_prefix = "[#{prefix}][#{repo}]"

    diff2html = DiffToHtml.new
    diff2html.diff_between_revisions rev1, rev2, repo, ref_name
    unless recipient.empty?
      diff2html.result.reverse.each_with_index do |result, i|
        nr = number(diff2html.result.size, i)
        emailer = Emailer.new project_path, recipient, result[:commit_info][:email], result[:commit_info][:author],
                       "#{subject_prefix}#{nr} #{result[:commit_info][:message]}", result[:text_content], result[:html_content], rev1, rev2, ref_name
        emailer.send
      end
    end
  end

  def self.number(total_entries, i)
    return '' if total_entries <= 1
    digits = total_entries < 10 ? 1 : 3
    '[' + sprintf("%0#{digits}d", i) + ']'
  end

end
