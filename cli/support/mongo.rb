require 'mongo'

module Support
  class Mongo
    def initialize(url)
      @cl = ::Mongo::Client.new(url)
    end

    def reset(cn, doc)
      Support::Display.info("resetting document (public_id=#{doc['public_id']})")
      @cl[cn].delete_many(public_id: doc['public_id'])
      @cl[cn].insert_one(doc)
    end

    def find_one_by_public_id(cn, id)
      @cl[cn].find(public_id: id).first
    end

    def remove_all(cn, &bl)
      @cl[cn].find({}).each { |doc| bl.call(doc) } if bl
      @cl[cn].delete_many({})
    end

    def delete_many_by_public_id(cn, ids)
      @cl[cn].delete_many('public_id' => { '$in' => ids.to_a })
    end
  end
end
