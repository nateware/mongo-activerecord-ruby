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
require 'mongo_record'
require 'active_support/core_ext'
require 'active_support/callbacks'
require 'active_record/callbacks'
require File.join(File.dirname(__FILE__), 'course')
require File.join(File.dirname(__FILE__), 'address')
require File.join(File.dirname(__FILE__), 'student')
require File.join(File.dirname(__FILE__), 'class_in_module')

# Include AR callbacks into MongoRecord
class MongoRecord::Base
  include ActiveRecord::Callbacks
end

class Track < MongoRecord::Base
  collection_name :tracks
  fields :artist, :album, :song, :track, :created_at

  def to_s
    # Uses both accessor methods and ivars themselves
    "artist: #{artist}, album: #{album}, song: #@song, track: #{@track ? @track.to_i : nil}"
  end
end

$callbacks_called = []
$dead_object = []
class Track1 < Track
  before_create do |r|
    r.song += ",before_create"
    $callbacks_called << :before_create
  end
  before_update do |r|
    r.song += ",before_update"
    $callbacks_called << :before_update
  end
  before_save do |r|
    r.song += ",before_save"
    $callbacks_called << :before_save
  end

  after_save do |r|
    r.track += 3
    $callbacks_called << :after_save
  end
  after_create do |r|
    r.track -= 2
    $callbacks_called << :after_create
  end
  after_update do |r|
    r.track *= 5
    $callbacks_called << :after_update
  end
  
  before_destroy do |r|
    $dead_object << r.song
    $callbacks_called << :before_destroy
  end
  after_destroy do |r|
    $dead_object << r.track
    $callbacks_called << :after_destroy
  end
end

# Same class, but this time class.name.downcase == collection name so we don't
# have to call collection_name.
class Rubytest < MongoRecord::Base
  fields :artist, :album, :song, :track
  def to_s
    "artist: #{artist}, album: #{album}, song: #{song}, track: #{track ? track.to_i : nil}"
  end
end

# Class without any fields defined to test inserting custom attributes
class Playlist < MongoRecord::Base
  collection_name :playlists
end

class CallbacksTest < Test::Unit::TestCase

  @@host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
  @@port = ENV['MONGO_RUBY_DRIVER_PORT'] || Mongo::Connection::DEFAULT_PORT
  @@db = Mongo::Connection.new(@@host, @@port).db('mongorecord-test')
  @@students = @@db.collection('students')
  @@courses = @@db.collection('courses')
  @@tracks = @@db.collection('tracks')
  @@playlists = @@db.collection('playlists')

  def setup
    super
    MongoRecord::Base.connection = @@db

    @@was_called = []
    @@students.clear
    @@courses.clear
    @@tracks.clear
    @@playlists.clear

    # Manually insert data without using MongoRecord::Base
    @@tracks.insert({:_id => Mongo::ObjectID.new, :artist => 'Thomas Dolby', :album => 'Aliens Ate My Buick', :song => 'The Ability to Swing'})
    @@tracks.insert({:_id => Mongo::ObjectID.new, :artist => 'Thomas Dolby', :album => 'Aliens Ate My Buick', :song => 'Budapest by Blimp'})
    @@tracks.insert({:_id => Mongo::ObjectID.new, :artist => 'Thomas Dolby', :album => 'The Golden Age of Wireless', :song => 'Europa and the Pirate Twins'})
    @@tracks.insert({:_id => Mongo::ObjectID.new, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'Garden Of Earthly Delights', :track => 1})
    @mayor_id = Mongo::ObjectID.new
    @@tracks.insert({:_id => @mayor_id, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'The Mayor Of Simpleton', :track => 2})
    @@tracks.insert({:_id => Mongo::ObjectID.new, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'King For A Day', :track => 3})

    @mayor_str = "artist: XTC, album: Oranges & Lemons, song: The Mayor Of Simpleton, track: 2"
    @mayor_song = 'The Mayor Of Simpleton'

    @spongebob_addr = Address.new(:street => "3 Pineapple Lane", :city => "Bikini Bottom", :state => "HI", :postal_code => "12345")
    @bender_addr = Address.new(:street => "Planet Express", :city => "New New York", :state => "NY", :postal_code => "10001")
    @course1 = Course.new(:name => 'Introductory Testing')
    @course2 = Course.new(:name => 'Advanced Phlogiston Combuston Theory')
    @score1 = Score.new(:for_course => @course1, :grade => 4.0)
    @score2 = Score.new(:for_course => @course2, :grade => 3.5)
  end

  def teardown
    @@students.clear
    @@courses.clear
    @@tracks.clear
    @@playlists.clear
    super
  end

  def test_class_callbacks_are_triggered
    $callbacks_called = []
    t = Track1.new(:artist => 'Porcupine Tree', :album => 'The Incident', :song => 'Your Unpleasant Family', :track => 7)
    assert_equal true, t.new_record?
    t.save
    assert_equal false, t.new_record?
    puts $callbacks_called.inspect

    assert_equal [:before_save, :before_create, :after_create, :after_save], $callbacks_called
    assert_equal 'Your Unpleasant Family,before_save,before_create', t.song
    assert_equal 8, t.track

    t2 = Track1.find_by_id(99)
    assert_equal t.song, t2.song
    assert_equal t.track, t2.track
    
    $callbacks_called = []
    t.track = 7
    t.save

    assert_equal [:before_save, :before_update, :after_update, :after_save], $callbacks_called

    $callbacks_called = []
    t.destroy

    assert_equal [:before_destroy, :after_destroy], $callbacks_called
  end

end
