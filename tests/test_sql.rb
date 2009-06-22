# Copyright 2009 10gen, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$LOAD_PATH[0,0] = File.join(File.dirname(__FILE__), '../lib')
require 'rubygems'
require 'test/unit'
require 'mongo_record/sql'

class SQLTest < Test::Unit::TestCase

  include MongoRecord::SQL

  def assert_done(t)
    assert !t.more?
    assert_nil t.next_token
  end

  def test_tokenizer
    t = Tokenizer.new('clicked = 1')
    assert_equal 'clicked', t.next_token
    assert_equal '=', t.next_token
    assert_equal 1, t.next_token
    assert_done t

    t = Tokenizer.new('clicked=1 ')
    assert_equal 'clicked', t.next_token
    assert_equal '=', t.next_token
    assert_equal 1, t.next_token
    assert !t.more?
    assert_done t

    t = Tokenizer.new('clicked2=1 ')
    assert_equal 'clicked2', t.next_token
    assert_equal '=', t.next_token
    assert_equal 1, t.next_token
    assert_done t

    t = Tokenizer.new('clicked=1 and foo = 5')
    assert_equal 'clicked', t.next_token
    assert_equal '=', t.next_token
    assert_equal 1, t.next_token
    assert_equal 'and', t.next_token
    assert_equal 'foo', t.next_token
    assert_equal '=', t.next_token
    assert_equal 5, t.next_token
    assert_done t

    t = Tokenizer.new("name = 'foo'")
    assert_equal 'name', t.next_token
    assert_equal '=', t.next_token
    assert_equal 'foo', t.next_token
    assert_done t

    t = Tokenizer.new("name = \"bar\"")
    assert_equal 'name', t.next_token
    assert_equal '=', t.next_token
    assert_equal 'bar', t.next_token
    assert_done t

    t = Tokenizer.new("name = 'foo''bar'")
    assert_equal 'name', t.next_token
    assert_equal '=', t.next_token
    assert_equal "foo'bar", t.next_token
    assert_done t

    t = Tokenizer.new("age <= 42")
    assert_equal 'age', t.next_token
    assert_equal '<=', t.next_token
    assert_equal 42, t.next_token
    assert_done t

    t = Tokenizer.new("age <> 42")
    assert_equal 'age', t.next_token
    assert_equal '<>', t.next_token
    assert_equal 42, t.next_token
    assert_done t
  end

  def test_strip_table_name
    w = Parser.parse_where("user.name = 'foo'", true)
    assert_equal 'foo', w['name']
    w = Parser.parse_where("schema.table.column = 'foo'", true)
    assert_equal 'foo', w['column']

    w = Parser.parse_where("user.name = 'foo'")
    assert_equal 'foo', w['user.name']
    w = Parser.parse_where("schema.table.column = 'foo'")
    assert_equal 'foo', w['schema.table.column']
  end

  def test_arrays
    w = Parser.parse_where("name in (1, 2, 42)")
    a = w['name'][:$in]
    assert_equal Array, a.class
    assert_equal 3, a.length
    assert_equal 1, a[0]
    assert_equal 2, a[1]
    assert_equal 42, a[2]
  end

  def test_regex
    p = Parser.new('')
    assert_equal /foo/i, p.regexp_from_string('%foo%')
    assert_equal /^foo/i, p.regexp_from_string('foo%')
    assert_equal /foo$/i, p.regexp_from_string('%foo')
    assert_equal /^foo$/i, p.regexp_from_string('foo')
  end

  def test_parser
    w = Parser.parse_where('clicked = 1 ')
    assert_equal 1, w['clicked']

    w = Parser.parse_where('clicked = 1 and z = 3')
    assert_equal 1, w['clicked']
    assert_equal 3, w['z']

    w = Parser.parse_where("name = 'foo'")
    assert_equal 'foo', w['name']

    w = Parser.parse_where("name like '%foo%'")
    assert_equal /foo/i, w['name']
    w = Parser.parse_where("name like 'foo%'")
    assert_equal /^foo/i, w['name']

    w = Parser.parse_where("foo <> 'bar'")
    assert_equal 'bar', w['foo'][:$ne]
    w = Parser.parse_where("foo != 'bar'")
    assert_equal 'bar', w['foo'][:$ne]

    w = Parser.parse_where("foo in (1, 2, 'a')")
    assert_equal "1, 2, a", w['foo'][:$in].join(', ')

    w = Parser.parse_where("foo in ('a', 'b', 'c')")
    assert_equal "a, b, c", w['foo'][:$in].join(', ')

    w = Parser.parse_where("name = 'the word '' or '' anywhere (surrounded by spaces) used to throw an error'")
    assert_equal "the word ' or ' anywhere (surrounded by spaces) used to throw an error", w['name']

    w = Parser.parse_where("foo between 1 and 3")
    assert_equal 1, w['foo'][:$gte]
    assert_equal 3, w['foo'][:$lte]

    w = Parser.parse_where("foo between 3 and 1")
    assert_equal 1, w['foo'][:$gte]
    assert_equal 3, w['foo'][:$lte]

    w = Parser.parse_where("foo between 'a' and 'Z'")
    assert_equal 'Z', w['foo'][:$gte] # 'Z' is < 'a'
    assert_equal 'a', w['foo'][:$lte]

    w = Parser.parse_where("foo between 'Z' and 'a'")
    assert_equal 'Z', w['foo'][:$gte]
    assert_equal 'a', w['foo'][:$lte]

    sql = "name = 'foo' or name = 'bar'"
    err = "sql parser can't handle ors yet: #{sql}"
    begin
      w = Parser.parse_where(sql)
      fail("expected to see \"#{err}\" error")
    rescue => ex
      assert_equal err, ex.to_s
    end
  end

end
