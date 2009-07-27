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

require 'mongo_record/base'

module MongoRecord

  # A MongoRecord::Subobject is an MongoRecord::Base subclass that disallows
  # many operations. Subobjects are those that are contained within and
  # saved with some other object.
  #
  # Using MongoRecord::Subobject is completely optional.
  #
  # As an example, say a Student object contains an Address. You might want
  # to make Address a subclass of Subobject so that you don't accidentally
  # try to save an address to a collection by itself.
  class Subobject < Base

    class << self # Class methods

      # Subobjects ignore the collection name.
      def collection_name(coll_name)
      end

      # Disallow find.
      def find(*args)
        complain("found")
      end

      # Disallow count.
      def count(*args)
        complain("counted")
      end

      # Disallow delete.
      def delete(id)
        complain("deleted")
      end
      alias_method :remove, :delete

      # Disallow destroy.
      def destroy(id)
        complain("destroyed")
      end

      # Disallow destroy_all.
      def destroy_all(conditions = nil)
        complain("destroyed")
      end

      # Disallow delete_all.
      def delete_all(conditions=nil)
        complain("deleted")
      end

      # Disallow create.
      def create(values_hash)
        complain("created")
      end

      private

      def complain(cant_do_this)
        raise "Subobjects can't be #{cant_do_this} by themselves. Use a subobject query."
      end

    end                       # End of class methods

    public

    # Subobjects do not have their own ids.
    def id=(val); raise "Subobjects don't have ids"; end

    # Subobjects do not have their own ids.
    # You'll get a deprecation warning if you call this outside of Rails.
    def id; raise "Subobjects don't have ids"; end

    # to_param normally returns the id of an object. Since subobjects don't
    # have ids, this is disallowed.
    def to_param; raise "Subobjects don't have ids"; end

    # Disallow new_record?
    def new_record?; raise "Subobjects don't have ids"; end

    # Disallow udpate.
    def update
      self.class.complain("updated")
    end

    # Disallow delete and remove.
    def delete
      self.class.complain("deleted")
    end
    alias_method :remove, :delete

  end

end
