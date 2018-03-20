require 'multi_json'
require_relative '../support/display'

module Init
  class Meta
    attr_reader :sections
    
    def self.load(env)
      Meta.new(MultiJson.decode(File.read('meta.json')).fetch(env, {}))
    end

    def initialize(o)
      @sections = o.map do |section, opts|
        require_relative "./#{section}"
        init_fn = lambda do
          Support::Display.info("init: #{section.upcase}")
          Kernel.const_get("Init::#{section.capitalize}").init(OpenStruct.new(opts))
        end
        OpenStruct.new({ name: section, init: init_fn })
      end
    end

    def init
      @sections.each do |section|
        section.init.call
      end
    end
  end
end
