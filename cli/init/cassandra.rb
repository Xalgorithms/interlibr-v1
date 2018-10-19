require_relative '../support/cassandra'
require_relative '../support/display'

module Init
  class Cassandra
    def self.init(opts)
      cl = Support::Cassandra.new(opts.url)
      Dir.glob('migrations/*.rb').sort.each do |fn|
        require_relative("../#{fn}")
        name = File.basename(fn)
        m = /^[0-9]+\_(.+)\.rb$/.match(name)
        Support::Display.info("running migration (name=#{name})")
        Kernel.const_get("#{m[1].capitalize}").up(cl)
      end
    end
  end
end
