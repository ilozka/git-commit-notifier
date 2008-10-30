require 'test/unit'
require 'jcode'
require File.dirname(__FILE__) + '/../lib/result_processor'
require File.dirname(__FILE__) + '/../lib/diff_to_html'

class ResultProcessorTest < Test::Unit::TestCase
  # button_to_remote 'create_btn'
  # submit_to_remote 'create_btn'

  def setup
    create_test_input
  end

  def test_processor
    proc = ResultProcessor.new(@diff)
    removal, addition = proc.results
    assert_equal 1, removal.size

    assert removal[0].include?('&nbsp;&nbsp;<span class="rr">b</span>')
    assert removal[0].include?('<span class="rr">ton</span>')

    assert_equal 1, removal[0].split('<span>').size # one occurrence (beginning of string)
    assert_equal 1, addition.size
    assert addition[0].include?('&nbsp;&nbsp;<span class="aa">s</span>')
    assert addition[0].include?('<span class="aa">bmi</span>')
    assert_equal 1, addition[0].split('<span>').size
  end

  def test_processor_with_almost_no_common_part
    @diff = [
      { :action => :match, :token => ' '},
      { :action => :match, :token => ' '},
      { :action => :discard_a, :token => 'button'},
      {:action => :discard_b, :token => 'submit'},
      { :action => :match, :token => 'x'}]

    proc = ResultProcessor.new(@diff)
    removal, addition = proc.results

    assert_equal 1, removal.size
    assert_equal '&nbsp;&nbsp;buttonx', removal[0] # no highlight
    assert_equal 1, addition.size
    assert_equal '&nbsp;&nbsp;submitx', addition[0] # no highlight
  end

  def test_close_span_tag_when_having_difference_at_the_end
    diff = []
    s1 = "  submit_to_remote 'create_btn', 'Create', :url => { :action => 'cre"
    s2 = "  submit_to_remote 'create_btn', 'Create', :url => { :action => 'sub"

    s1[0..s1.size-6].each_char do |c|
      diff << { :action => :match, :token => c}
    end
    diff << { :action => :discard_a, :token => 'c'}
    diff << { :action => :discard_a, :token => 'r'}
    diff << { :action => :discard_a, :token => 'e'}
    diff << { :action => :discard_b, :token => 's'}
    diff << { :action => :discard_b, :token => 'u'}
    diff << { :action => :discard_b, :token => 'b'}

    proc = ResultProcessor.new(diff)
    removal, addition = proc.results
    assert_equal 1, removal.size
    assert removal[0].include?('action&nbsp;=&gt;<span class="rr">cre</span>')

    assert_equal 1, addition.size
    assert addition[0].include?('action&nbsp;=&gt;<span class="aa">sub</span>')
  end

  def create_test_input
    @diff = []
    s1 = "  button_to_remote 'create_btn', 'Create', :url => { :action => 'create' }"
    s2 = "  submit_to_remote 'create_btn', 'Create', :url => { :action => 'create' }"

    @diff = [
     [:match,    ' '],
     [:match,    ' '],
     [:discard_a,'b'],
     [:discard_b,'s'],
     [:match,    'u'],
     [:discard_b,'b'],
     [:discard_b,'m'],
     [:discard_b,'i'],
     [:match,    't'],
     [:discard_a,'t'],
     [:discard_a,'o'],
     [:discard_a,'n']]
    @diff = @diff.collect { |d| { :action => d.first, :token => d.last}}

    s1[@diff.size..-1].each_char do |c|
      @diff << { :action => :match, :token => c}
    end
  end

end
