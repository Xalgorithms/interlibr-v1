require 'multi_json'
require 'radish/documents/core'
require_relative '../support/display'

require_relative 'components/revisions/packages'

module Init
  class Meta
    include Radish::Documents::Core
    
    def self.load(env)
      Meta.new(MultiJson.decode(File.read('meta.json')).fetch(env, {}))
    end

    def sections(k = nil)
      k ? @sections.fetch(k, nil) : @sections.values
    end
    
    def initialize(o)
      @sections = o.inject({}) do |sections, (section, opts)|
        require_relative "./#{section}"
        init_fn = lambda do
          Support::Display.info("init: #{section.upcase}")
          Kernel.const_get("Init::#{section.capitalize}").init(OpenStruct.new(opts))
        end
        sections.merge(section => OpenStruct.new(name: section, init: init_fn, opts: opts))
      end
    end

    def init
      @sections.values.each do |section|
        section.init.call
      end
    end

    def invoke(n, act)
      c = get(components, n)
      if c
        begin
          c.send(act)
        rescue NoMethodError => e
          Support::Display.error("no such action (n=#{n}; act=#{act}; e=#{e})")
        end
      else
        Support::Display.error("no such component (n=#{n})")
      end
    end

    def components
      @components ||= {
        'revisions' => {
          'packages' => Init::Components::Revisions::Packages.new(self),
        }
      }
    end
  end
end
