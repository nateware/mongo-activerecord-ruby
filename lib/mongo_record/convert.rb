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

# Mongo stores trees of JSON-like documents. These +to_mongo_value+ methods
# covert objects to Hash values, which are converted by the Mongo driver
# to the proper types.

class Object
  # Convert an Object to a Mongo value. Used by MongoRecord::Base when saving
  # data to Mongo.
  def to_mongo_value
    self
  end

  # From Rails
  def instance_values #:nodoc:
    instance_variables.inject({}) do |values, name|
      values[name.to_s[1..-1]] = instance_variable_get(name)
      values
    end
  end

end

class Array
  # Convert an Array to a Mongo value. Used by MongoRecord::Base when saving
  # data to Mongo.
  def to_mongo_value
    self.collect {|v| v.to_mongo_value}
  end
end

class Hash
  # Convert an Hash to a Mongo value. Used by MongoRecord::Base when saving
  # data to Mongo.
  def to_mongo_value
    h = {}
    self.each {|k,v| h[k] = v.to_mongo_value}
    h
  end

  # Same symbolize_keys method used in Rails
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

  def symbolize_keys!
    self.replace(self.symbolize_keys)
  end
end
