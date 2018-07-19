require 'rainbow'

module Support
  class Display
    def self.info(m, tag = nil)
      puts Rainbow("# #{maybe_with_tag(m, tag)}").silver
    end

    def self.info_stage(m, tag = nil)
      puts Rainbow("\n=> #{maybe_with_tag(m.upcase, tag)}").blue.bold
    end

    def self.info_strong(m, tag = nil)
      puts Rainbow("# #{maybe_with_tag(m, tag)}").green.bold
    end

    def self.error(m, tag = nil)
      puts Rainbow("! #{maybe_with_tag(m, tag)}").red
    end

    def self.error_strong(m, tag = nil)
      puts Rainbow("! #{maybe_with_tag(m, tag)}").red.bold
    end

    def self.warn(m, tag = nil)
      puts Rainbow("? #{maybe_with_tag(m, tag)}").yellow
    end

    def self.give(m, tag = nil)
      puts Rainbow("> #{maybe_with_tag(m, tag)}").yellow
    end

    def self.got_ok(m, tag = nil)
      puts Rainbow("< #{maybe_with_tag(m, tag)}").green
    end

    def self.got_warn(m, tag = nil)
      puts Rainbow("< #{maybe_with_tag(m, tag)}").yellow
    end
    
    def self.got_fail(m, tag = nil)
      puts Rainbow("< #{maybe_with_tag(m, tag)}").red
    end

    def self.got(resp)
      if resp.status == 200
        got_ok(yield(resp.body))
      else
        got_fail('failed')
      end
    end

    private

    def self.maybe_with_tag(m, tag)
      tag ? "(#{tag}) #{m}" : m
    end
  end
end
