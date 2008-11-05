require 'rubygems'
require 'mocha'
require 'cgi'
require 'test/unit'
require 'hpricot'
require File.dirname(__FILE__) + '/test_helper'

require File.dirname(__FILE__) + '/../lib/diff_to_html'
require File.dirname(__FILE__) + '/../lib/git'

class DiffToHtmlTest < Test::Unit::TestCase

  def test_multiple_commits
    path = File.dirname(__FILE__) + '/fixtures/'
    Git.expects(:log).with(REVISIONS.first, REVISIONS.last).returns(read_file(path + 'git_log'))
    REVISIONS.each do |rev|
      Git.expects(:show).with(rev).returns(read_file(path + 'git_show_' + rev))
    end

    diff = DiffToHtml.new
    diff.diff_between_revisions REVISIONS.first, REVISIONS.last, 'testproject', 'master'
    assert_equal 4, diff.result.size # one result for each of the commits

    diff.result.each do |html|
      assert !html.include?('@@') # diff correctly processed
    end

    # first commit
    hp = Hpricot diff.result.first[:html_content]
    assert_equal 2, (hp/"table").size # 8 files updated - one table for each of the files
    (hp/"table/tr/").each do |td|
      if td.inner_html == "require&nbsp;'iconv'"
        # first added line in changeset a4629e707d80a5769f7a71ca6ed9471015e14dc9
        assert_equal '', td.parent.search('td')[0].inner_text # left
        assert_equal '2', td.parent.search('td')[1].inner_text # right
        assert_equal "require&nbsp;'iconv'", td.parent.search('td')[2].inner_html # change
      end
    end

    # second commit
    hp = Hpricot diff.result[1][:html_content]
    assert_equal 1, (hp/"table").size # 1 file updated

    # third commit - dce6ade4cdc2833b53bd600ef10f9bce83c7102d
    hp = Hpricot diff.result[2][:html_content]
    assert_equal 6, (hp/"table").size # 6 files updated
    assert_equal 'Added binary file railties/doc/guides/source/images/icons/callouts/11.png', (hp/"h2")[1].inner_text
    assert_equal 'Deleted binary file railties/doc/guides/source/icons/up.png', (hp/"h2")[2].inner_text
    assert_equal 'Deleted file railties/doc/guides/source/icons/README', (hp/"h2")[3].inner_text
    assert_equal 'Added file railties/doc/guides/source/images/icons/README', (hp/"h2")[4].inner_text

    # fourth commit - 51b986619d88f7ba98be7d271188785cbbb541a0
    hp = Hpricot diff.result[3][:html_content]
    assert_equal 3, (hp/"table").size # 3 files updated
    (hp/"table/tr/").each do |td|
      if td.inner_html =~ /create_btn/
        cols = td.parent.search('td')
        ['405', '408', ''].include? cols[0].inner_text # line 405 changed
      end
    end
  end

  def test_single_commit
    path = File.dirname(__FILE__) + '/fixtures/'
    Git.expects(:log).never
    Git.expects(:show).with(REVISIONS.first).returns(read_file(path + 'git_show_' + REVISIONS.first))

    diff = DiffToHtml.new
    diff.diff_between_revisions REVISIONS.first, REVISIONS.first, 'testproject', 'master'
    assert_equal 1, diff.result.size # single result for a single commit
    assert_equal 'Allow use of :path_prefix and :name_prefix outside of namespaced routes', diff.result.first[:commit_info][:message]
    assert_equal 'Tom Stuart', diff.result.first[:commit_info][:author]
    assert_equal 'tom@experthuman.com', diff.result.first[:commit_info][:email]

    hp = Hpricot(diff.result.first[:html_content])
    assert !diff.result.first[:html_content].include?('@@')
    assert_equal 2, (hp/"table").size # 2 files updated
    (hp/"table/tr/").each do |td|
      if td.inner_html == "require&nbsp;'iconv'"
        # first added line in changeset a4629e707d80a5769f7a71ca6ed9471015e14dc9
        assert_equal '', td.parent.search('td')[0].inner_text # left
        assert_equal '2', td.parent.search('td')[1].inner_text # right
        assert_equal "require&nbsp;'iconv'", td.parent.search('td')[2].inner_html # change
      end
    end
  end

  def test_tokenize
    s = "keys = I18n.send :normalize_translation_keys, locale, key, scope"
    diff = DiffToHtml.new
    tokens = diff.tokenize_string(s)

    assert_equal ['keys', ' ', '=', ' ', 'I18n', '.', 'send',' ',':','normalize','_','translation','_','keys',',',' ','locale',',',' ',
              'key',',',' ','scope'], tokens
  end

end
