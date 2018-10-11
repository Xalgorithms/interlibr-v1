require 'rainbow'

module Support
  class Display
    def self.info(m, tag = nil, args = {})
      puts Rainbow("# #{maybe_with_tag_or_args(m, tag, args)}").silver
    end

    def self.info_stage(m, tag = nil, args = {})
      puts Rainbow("\n=> #{maybe_with_tag_or_args(m.upcase, tag, args)}").blue.bold
    end

    def self.info_strong(m, tag = nil, args = {})
      puts Rainbow("# #{maybe_with_tag_or_args(m, tag, args)}").green.bold
    end

    def self.error(m, tag = nil, args = {})
      puts Rainbow("! #{maybe_with_tag_or_args(m, tag, args)}").red
    end

    def self.error_strong(m, tag = nil, args = {})
      puts Rainbow("! #{maybe_with_tag_or_args(m, tag, args)}").red.bold
    end

    def self.warn(m, tag = nil, args = {})
      puts Rainbow("? #{maybe_with_tag_or_args(m, tag, args)}").yellow
    end

    def self.give(m, tag = nil, args = {})
      puts Rainbow("> #{maybe_with_tag_or_args(m, tag, args)}").yellow
    end

    def self.got_ok(m, tag = nil, args = {})
      puts Rainbow("< #{maybe_with_tag_or_args(m, tag, args)}").green
    end

    def self.got_warn(m, tag = nil, args = {})
      puts Rainbow("< #{maybe_with_tag_or_args(m, tag, args)}").yellow
    end
    
    def self.got_fail(m, tag = nil, args = {})
      puts Rainbow("< #{maybe_with_tag_or_args(m, tag, args)}").red
    end

    def self.got(resp)
      if resp.status == 200
        m = yield(resp.body)
        if m.class == Array
          got_ok(*m)
        else
          got_ok(m)
        end
      else
        got_fail('failed')
      end
    end

    private

    def self.maybe_with_tag_or_args(m, tag, args)
      ms = tag ? "(#{tag}) #{m}" : m
      as = args.any? ? args.map { |k, v| "#{k}=#{v}" }.join('; ') : nil
      as ? "#{ms} [#{as}]" : ms
    end
  end
end
