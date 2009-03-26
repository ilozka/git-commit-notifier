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
    @diff_result << "<tr#{klass}>\n<td class=\"ln\">#{line[:removed]}</td>\n<td class=\"ln\">#{line[:added]}</td>\n<td>#{padding}#{content}</td></tr>"
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
    @diff_result << operation_description
    @diff_result << '<table>'
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
      @diff_result << '</table>'
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

    @diff_result = []
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

      op = line[0,1]
      @left_ln.nil? || op == '@' ? process_info_line(line, op) : process_code_line(line, op)
    end
    add_changes_to_result
    @diff_result.join("\n")
  end

  def process_code_line(line, op)
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

  def process_info_line(line, op)
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
    result = { :message => [], :commit => '', :author => '', :date => '', :email => '' }
    content.split("\n").each do |line|
      if line =~ /^diff/ # end of commit info, return results
        return result
      elsif line =~ /^commit/
        result[:commit] = line[7..-1]
      elsif line =~ /^Author/
        result[:author], result[:email] = author_name_and_email(line[8..-1])
      elsif line =~ /^Date/
        result[:date] = line[8..-1]
      else
        clean_line = line.strip
        result[:message] << clean_line unless clean_line.empty?
      end
    end
    result
  end

  def message_array_as_html(message)
    message.collect { |m| CGI.escapeHTML(m)}.join("<br />")
  end

  def author_name_and_email(info)
    # input string format: "autor name <author@email.net>"
    result = info.scan(/(.*)\s<(.*)>/)[0]
    return result if result.is_a?(Array) && result.size == 2 # normal operation
    # incomplete author info - return it as author name
    return [info, ''] if result.nil?
  end

  def first_sentence(message_array)
    msg = message_array.first.to_s.strip
    return message_array.first if msg.empty? || msg =~ /^Merge\:/
    msg
  end

  def diff_between_revisions(rev1, rev2, repo, branch)
    @result = []
    if rev1 == rev2
      commits = [[rev1]]
    else
      log = Git.log(rev1, rev2)
      commits = log.scan /^commit\s([a-f0-9]+)/
    end

    previous_file = THIS_FILE ? File.join(File.dirname(THIS_FILE), "../config/previously.txt") : "/tmp/previously.txt"
    previous_list = (File.read(previous_file).split("\n") if File.exist?(previous_file)) || []
    commits.reject!{|c| c.find{|sha| previous_list.include?(sha)} }
    current_list = (previous_list + commits.flatten).last(1000)
    File.open(previous_file, "w"){|f| f << current_list.join("\n") } unless current_list.empty?

    commits.each_with_index do |commit, i|
      raw_diff = Git.show(commit[0])
      raise "git show output is empty" if raw_diff.empty?
      @last_raw = raw_diff

      commit_info = extract_commit_info_from_git_show_output(raw_diff)

      title = "<div class=\"title\">"
      title += "<strong>Message:</strong> #{message_array_as_html commit_info[:message]}<br />\n"
      title += "<strong>Commit</strong> #{commit_info[:commit]}<br />\n"
      title += "<strong>Branch:</strong> #{branch}\n<br />" unless branch =~ /\/head/
      title += "<strong>Date:</strong> #{CGI.escapeHTML commit_info[:date]}\n<br />"
      title += "<strong>Author:</strong> #{CGI.escapeHTML(commit_info[:author])} &lt;#{commit_info[:email]}&gt;\n</div>"

      text = "#{raw_diff}\n\n\n"

      html = title
      html += diff_for_revision(extract_diff_from_git_show_output(raw_diff))
      html += "<br /><br />"
      commit_info[:message] = first_sentence(commit_info[:message])
      @result << {:commit_info => commit_info, :html_content => html, :text_content => text }
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
