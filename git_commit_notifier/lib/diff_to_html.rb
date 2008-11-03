require 'rubygems'
require 'diff/lcs'
require File.dirname(__FILE__) + '/result_processor'

def escape_content(s)
  CGI.escapeHTML(s).gsub(" ", "&nbsp;")
end

class DiffToHtml
  attr_accessor :file_prefix
  attr_reader :result

  def range_info(range)
    range.match(/^@@ \-(\d+),\d+ \+(\d+),\d+ @@/)
    left_ln = Integer($1)
    right_ln = Integer($2)
    return left_ln, right_ln
  end

  def line_class(line)
    if line[:op] == :removal
      return " class=\"r\""
    elsif line[:op] == :addition
      return " class=\"a\""
    else
      return ''
    end
  end

  def add_block_to_results(block, escape)
    return if block.empty?
    block.each do |line|
      add_line_to_result(line, escape)
    end
  end

  def add_line_to_result(line, escape)
    klass = line_class(line)
    content = escape ? escape_content(line[:content]) : line[:content]
    padding = '&nbsp;' if klass != ''
    @diff_result += "<tr#{klass}>\n<td class=\"ln\">#{line[:removed]}</td>\n<td class=\"ln\">#{line[:added]}</td>\n<td>#{padding}#{content}</td></tr>\n"
  end

  def extract_block_content(block)
    block.collect { |b| b[:content]}.join("\n")
  end

  def lcs_diff(removals, additions)
    # arrays always have at least 1 element
    callback = DiffCallback.new

    s1 = extract_block_content(removals)
    s2 = extract_block_content(additions)

    s1 = tokenize_string(s1)
    s2 = tokenize_string(s2)

    Diff::LCS.traverse_balanced(s1, s2, callback)

    processor = ResultProcessor.new(callback.tags)

    diff_for_removals, diff_for_additions = processor.results
    result = []

    ln_start = removals[0][:removed]
    diff_for_removals.each_with_index do |line, i|
      result << { :removed => ln_start + i, :added => nil, :op => :removal, :content => line}
    end

    ln_start = additions[0][:added]
    diff_for_additions.each_with_index do |line, i|
      result << { :removed => nil, :added => ln_start + i, :op => :addition, :content => line}
    end

    result
  end

  def tokenize_string(str)
    # tokenize by non-alphanumerical characters
    tokens = []
    token = ''
    str = str.split('')
    str.each_with_index do |char, i|
      alphanumeric = !char.match(/[a-zA-Z0-9]/).nil?
      if !alphanumeric || str.size == i+1
        token += char if alphanumeric
        tokens << token unless token.empty?
        tokens << char unless alphanumeric
        token = ''
      else
        token += char
      end
    end
    return tokens
  end

  def operation_description
    binary = @binary ? 'binary ' : ''
    if @file_removed
      op = "Deleted"
    elsif @file_added
      op = "Added"
    else
      op = "Changed"
    end
    header = "#{op} #{binary}file #{@current_file_name}"
    "<h2>#{header}</h2>\n"
  end

  def add_changes_to_result
    return if @current_file_name.nil?
    @diff_result += operation_description
    @diff_result += '<table>'
    unless @diff_lines.empty?
      removals = []
      additions = []
      @diff_lines.each do |line|
        if [:addition, :removal].include?(line[:op])
          removals << line if line[:op] == :removal
          additions << line if line[:op] == :addition
        end
        if line[:op] == :unchanged || line == @diff_lines.last # unchanged line or end of block, add prev lines to result
          if removals.size > 0 && additions.size > 0 # block of removed and added lines - perform intelligent diff
            add_block_to_results(lcs_diff(removals, additions), escape = false)
          else # some lines removed or added - no need to perform intelligent diff
            add_block_to_results(removals + additions, escape = true)
          end
          removals = []
          additions = []
          add_line_to_result(line, escape = true) if line[:op] == :unchanged
        end
      end
      @diff_lines = []
      @diff_result +='</table>'
    end
    # reset values
    @right_ln = nil
    @left_ln = nil
    @file_added = false
    @file_removed = false
    @binary = false
  end

  def diff_for_revision(content)
    @left_ln = @right_ln = nil

    @diff_result = ""
    @diff_lines = []
    @removed_files = []
    @current_file_name = nil

    content.split("\n").each do |line|
      if line =~ /^diff\s\-\-git/
        line.match(/diff --git a\/(.*)\sb\//)
        file_name = $1
        add_changes_to_result
        @current_file_name = file_name
      end

      @left_ln.nil? ? process_info_line(line) : process_code_line(line)
    end
    add_changes_to_result
    @diff_result
  end

  def process_code_line(line)
    op = line[0,1]
    if op == '-'
      @diff_lines << { :removed => @left_ln, :added => nil, :op => :removal, :content => line[1..-1] }
      @left_ln += 1
    elsif op == '+'
      @diff_lines << { :added => @right_ln, :removed => nil, :op => :addition, :content => line[1..-1] }
      @right_ln += 1
    else @right_ln
      @diff_lines << { :added => @right_ln, :removed => @left_ln, :op => :unchanged, :content => line }
      @right_ln += 1
      @left_ln += 1
    end
  end

  def process_info_line(line)
    op = line[0,1]
    if line =~/^deleted\sfile\s/
      @file_removed = true
    elsif line =~ /^\-\-\-\s/ && line =~ /\/dev\/null/
      @file_added = true
    elsif line =~ /^\+\+\+\s/ && line =~ /\/dev\/null/
      @file_removed = true
    elsif line =~ /^Binary files \/dev\/null/ # Binary files /dev/null and ... differ (addition)
      @binary = true
      @file_added = true
    elsif line =~ /\/dev\/null differ/ # Binary files ... and /dev/null differ (removal)
      @binary = true
      @file_removed = true
    elsif op == '@'
      @left_ln, @right_ln = range_info(line)
    end
  end

  def extract_diff_from_git_show_output(content)
    diff = []
    diff_found = false
    content.split("\n").each do |line|
      diff_found = true if line =~ /^diff \-\-git/
      next unless diff_found
      diff << line
    end
    diff.join("\n")
  end

  def extract_commit_info_from_git_show_output(content)
    message = []
    commit = author = date = email = ''
    content.split("\n").each do |line|
      if line =~ /^diff/
        return [commit, author, email, date, message]
      elsif line =~ /^commit/
        commit = line[7..-1]
      elsif line =~ /^Author/
        author, email = author_name_and_email(line[8..-1])
      elsif line =~ /^Date/
        date = line[8..-1]
      else
        clean_line = line.strip
        message << clean_line unless clean_line.empty?
      end
    end
  end

  def message_array_as_html(message)
    message.collect { |m| CGI.escapeHTML(m)}.join("<br />")
  end

  def author_name_and_email(info)
    info.match /(.*)<(.*)>/
    [$1, $2]
  end

  def diff_between_revisions(rev1, rev2, repo, branch)
    @result = []
    if rev1 == rev2
      commits = [[rev1]]
    else
      log = Git.log(rev1, rev2)
      commits = (log.scan /commit\s([a-f0-9]+)/)
    end

    commits.each_with_index do |commit, i|
      raw_diff = Git.show(commit[0])
      @last_raw = raw_diff

      commit, author, email, date, message = extract_commit_info_from_git_show_output(raw_diff)

      title = "<div class=\"title\">"
      title += "<strong>Message:</strong> #{message_array_as_html message}<br />\n"
      title += "<strong>Commit</strong> #{commit}<br />\n"
      title += "<strong>Branch:</strong> #{branch}\n<br />" unless branch =~ /\/head/
      title += "<strong>Date:</strong> #{CGI.escapeHTML date}\n<br />"
      title += "<strong>Author:</strong> #{CGI.escapeHTML(author)} &lt;#{email}&gt;\n</div>"

      text = "#{raw_diff}\n\n\n"

      html = title
      html += diff_for_revision(extract_diff_from_git_show_output(raw_diff))
      html += "<br /><br />"
      @result << {:author_name => author, :author_email => email,
                  :message => message.first[0..120], :html_content => html, :text_content => text }
    end
  end
end

class DiffCallback
  attr_reader :tags

  def initialize
    @tags = []
  end

  def match(event)
    @tags << { :action => :match, :token => event.old_element }
  end

  def discard_b(event)
    @tags << { :action => :discard_b, :token => event.new_element }
  end

  def discard_a(event)
    @tags << { :action => :discard_a, :token => event.old_element }
  end

end
