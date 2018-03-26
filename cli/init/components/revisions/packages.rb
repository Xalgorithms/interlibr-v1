require_relative '../../../support/display'
require_relative '../../../support/mongo'

module Init
  module Components
    module Revisions
      class Packages
        def initialize(meta)
          @meta = meta
        end
        
        def clear
          Support::Display.warn("removing all packages from the revisions service data (url=#{@meta.sections('mongo').opts['url']})")
          cl = Support::Mongo.new(@meta.sections('mongo').opts['url'])
          related = { rules: Set.new, tables: Set.new }
          cl.remove_all('packages') do |doc|
            doc['revisions'].each do |rev|
              related = related.merge(rules: related[:rules] + Set.new(rev['contents']['rules']))
              related = related.merge(tables: related[:tables] + Set.new(rev['contents']['tables']))
            end
          end

          related.each do |cn, ids|
            cl.delete_many_by_public_id(cn, ids)
          end
          cl.delete_many_by_public_id('meta', related[:rules] + related[:tables])
        end
      end
    end
  end
end
