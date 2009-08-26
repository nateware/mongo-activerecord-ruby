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
require 'logger'
require 'mongo'
require 'mongo_record/log_device.rb'

class LoggerTest < Test::Unit::TestCase

  MAX_RECS = 3

  @@host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
  @@port = ENV['MONGO_RUBY_DRIVER_PORT'] || Mongo::Connection::DEFAULT_PORT
  @@db = Mongo::Connection.new(@@host, @@port).db('mongorecord-test')

  def setup
    @@db.drop_collection('testlogger') # can't remove recs from capped colls
    MongoRecord::LogDevice.connection = @@db
    # Create a log device with a max of MAX_RECS records
    @logger = Logger.new(MongoRecord::LogDevice.new('testlogger', :size => 1_000_000, :max => MAX_RECS))
  end

  def teardown
    @@db.drop_collection('testlogger') # can't remove recs from capped colls
  end

  # We really don't have to test much more than this. We can trust that Mongo
  # works properly.
  def test_max
    assert_not_nil @@db
    assert_equal @@db.name, MongoRecord::LogDevice.connection.name
    collection = MongoRecord::LogDevice.connection.collection('testlogger')
    MAX_RECS.times { |i|
      @logger.debug("test message #{i+1}")
      assert_equal i+1, collection.count()
    }

    MAX_RECS.times { |i|
      @logger.debug("test message #{i+MAX_RECS+1}")
      assert_equal MAX_RECS, collection.count()
    }
  end

  def test_alternate_connection
    old_db = @@db
    alt_db = Mongo::Connection.new(@@host, @@port).db('mongorecord-test-log-device')
    begin
      @@db = nil
      MongoRecord::LogDevice.connection = alt_db

      logger = Logger.new(MongoRecord::LogDevice.new('testlogger', :size => 1_000_000, :max => MAX_RECS))
      logger.debug('test message')

      coll = alt_db.collection('testlogger')
      assert_equal 1, coll.count()
      rec = coll.find_one
      assert_not_nil rec
      assert_match /test message/, rec['msg']
    rescue => ex
      fail ex.to_s
    ensure
      @@db = old_db
      MongoRecord::LogDevice.connection = @@db
      alt_db.drop_collection('testlogger')
    end
  end

end
