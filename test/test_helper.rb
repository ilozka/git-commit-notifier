require 'test/unit'

unless defined? REVISIONS
  REVISIONS = ['e28ad77bba0574241e6eb64dfd0c1291b221effe', # 2 files updated
             'a4629e707d80a5769f7a71ca6ed9471015e14dc9', # 1 file updated
             'dce6ade4cdc2833b53bd600ef10f9bce83c7102d', # 6 files updated
             '51b986619d88f7ba98be7d271188785cbbb541a0'] # 3 files updated

end

class Test::Unit::TestCase

  def read_file(name)
    out = ''
    File.open(name).each { |line|
      out += line
    }
    out
  end

end
