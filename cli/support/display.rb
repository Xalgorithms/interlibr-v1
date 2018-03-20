require 'rainbow'

module Support
  class Display
    def self.info(m)
      puts Rainbow("# #{m}").green
    end

    def self.info_strong(m)
      puts Rainbow("# #{m}").green.bold
    end

    def self.error(m)
      puts Rainbow("! #{m}").red
    end

    def self.error_strong(m)
      puts Rainbow("! #{m}").red.bold
    end

    def self.warn(m)
      puts Rainbow("# #{m}").yellow
    end

    def self.give(m)
      puts Rainbow("> #{m}").yellow
    end

    def self.got_ok(m)
      puts Rainbow("< #{m}").green
    end

    def self.got_warn(m)
      puts Rainbow("< #{m}").yellow
    end
    
    def self.got_fail(m)
      puts Rainbow("< #{m}").red
    end

    def self.got(resp)
      if resp.status == 200
        got_ok(yield(resp.body))
      else
        got_fail('failed')
      end
    end
  end
end
