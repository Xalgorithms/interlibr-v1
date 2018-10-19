require 'active_support/core_ext/hash'
require 'faker'
require 'multi_json'
require 'terminal-table'
require 'thor'
require 'thread'
require 'timeout'
require 'xa/rules/parse/content'

require_relative '../clients/events'
require_relative '../clients/query'
require_relative '../clients/revisions'
require_relative '../clients/schedule'
require_relative '../support/display'
require_relative '../support/cassandra'
require_relative '../support/kafka'
require_relative '../support/mongo'

module Subcommands
  class Test < Thor
    include XA::Rules::Parse::Content

    class Barrier
      def initialize
        @mutex = Mutex.new
        @cond = ConditionVariable.new
      end

      def signal
        @mutex.synchronize {
          @cond.signal
        }
      end

      def wait
        @mutex.synchronize {
          @cond.wait(@mutex)
        }
      end
    end

    class SynchroEventsListener
      def initialize(events_url, ws_url, topic)
        Support::Display.info("connecting to service (events_url=#{events_url}, ws_url=#{ws_url})", "events")
        @topic = topic
        @ready = Barrier.new
        @registered = false
        @registered_mutex = Mutex.new
        @cl = Clients::Events.new(events_url, ws_url)
        @reqs_q = Queue.new
        @items_q = Queue.new
      end

      def listen
        Support::Display.info("starting events thread", "events")
        @thr = Thread.new do
          @req_ids = Set.new
          @q_req_ids = Set.new
          @cl.subscribe([@topic], {
                          service: {
                            registered: method(:on_registered)
                          },
                          @topic.to_sym => {
                            notified: method(:on_notified)
                          }
                        })
        end
      end

      def thread_alive?
        @thr.join(0.75)
        @thr && @thr.alive?
      end

      def wait_until_ready
        if thread_alive?
          Support::Display.info("waiting for listener to be ready", "events")
          @registered || @ready.wait
        else
          Support::Display.warn("thread is not alive", "events")
        end
      end

      def drain_received_q
        items = Set.new
        while !@items_q.empty?
          items << @items_q.pop
        end
        items
      end
      
      def join(expected_req_ids, items_fn = nil)
        if thread_alive?
          received_items = drain_received_q
          received_ids = received_items.map { |it| it[:request_id] }
          if received_ids.sort == expected_req_ids.sort
            Support::Display.info("all requests have arrived", "events")
            items_fn.call(received_items) if items_fn
          else
            Support::Display.info("waiting for listener thread to exit", "events")
            expected_req_ids.each { |req_id| @reqs_q << req_id }
            if !@thr.join(10)
              Support::Display.warn("all events probably arrived early, synchronizing with events thread", "events")
              received_items = received_items + drain_received_q
              received_ids = received_items.map { |it| it[:request_id] }
              if expected_req_ids.size != received_ids.size
                Support::Display.warn("mismatched request sizes (reqs=#{expected_req_ids.size}; received_ids=#{received_ids.size})", "events")
              end

              items_fn.call(received_items) if items_fn
            else
              Support::Display.info("thread finished", "events")
              items_fn.call(received_items) if items_fn
            end
          end
        else
          Support::Display.warn("thread is not alive", "events")
        end
      end

      private

      def on_registered(o)
        Support::Display.got_ok("event listener is ready", "events")
        @registered_mutex.synchronize { @registered = true }
        @ready.signal
        false
      end

      def on_notified(o)
        Support::Display.got_ok("received notification", "events")
        if ('execution' == o['context']['task'] && 'end' == o['context']['action'])
          Support::Display.info('handling execution/end')
          req_id = o['args']['request_id']
          @req_ids << req_id
          @items_q << { request_id: req_id }
        elsif ('compute' == o['context']['task'] && 'effective' == o['context']['action'])
          Support::Display.info('handling compute/effective')
          req_id = o['args']['document_id']
          rule_id = o['args']['rule_id']
          @items_q << { request_id: req_id, rule_id: rule_id }
        elsif ('compute' == o['context']['task'] && 'applicable' == o['context']['action'])
          Support::Display.info('handling compute/applicable')
          req_id = o['args']['document_id']
          rule_id = o['args']['rule_id']
          @items_q << { request_id: req_id, rule_id: rule_id }
        end

        while !@reqs_q.empty?
          @q_req_ids << @reqs_q.pop
        end

        @q_req_ids.any? && @q_req_ids.subset?(@req_ids)
      end
    end

    class RuleExpectations
      def initialize(url)
        @qcl = Clients::Query.new(url || 'http://localhost:8000')
      end

      def add_expected_rules(rules)
        @ex_rules = rules.inject(Set.new) do |set, rule|
          set << "#{rule[:ns]}:#{rule[:name]}:#{rule[:version]}"
        end
      end

      def add_actual_rule_ids(ids)
        @ac_rule_ids = ids
      end

      def check
        Support::Display.info("checking (ex=#{@ex_rules.length}; ac=#{@ac_rule_ids.length})", "expectations")
        if @ex_rules.length == @ac_rule_ids.length
          matched = @ac_rule_ids.select do |rule_id|
            ac_rule = @qcl.rule(rule_id)
            @ex_rules.include?("#{ac_rule['ns']}:#{ac_rule['name']}:#{ac_rule['version']}")
          end
          Support::Display.info("matching rules (len=#{matched.length})", "expectations")
          if matched.length == @ex_rules.length
            Support::Display.info_strong("all matching rules found", "expectations")
          else
            Support::Display.error("missing rules in results", "expectations")
          end
        else
          Support::Display.error("lengths are not the same", "expectations")
        end
      end
    end
    
    class TableExpectations
      def initialize(url)
        @qcl = Clients::Query.new(url || 'http://localhost:8000')
        @reqs = {}
      end
      
      def add(req_id, name, fn)
        Support::Display.info("adding expectations (req_id=#{name}; name=#{name}; fn=#{fn})", "expectations")
        ex = File.exist?(fn) ? MultiJson.decode(IO.read(fn)) : {}
        @reqs = @reqs.merge(req_id => { name: name, expected: ex })
      end

      def self.show_table(section, name, tbl, label=nil)
        label_s = label ? "[#{label}] " : ''
        headings = tbl.inject(Set.new) do |set, row|
          set + Set.new(row.keys)
        end
        term_table = Terminal::Table.new(
          style: { width: 120 },
          title: "#{label_s}#{section}:#{name}",
          headings: headings,
          rows: tbl.map do |row|
            headings.map { |k| row.fetch(k, nil) }
          end)
        puts term_table
        puts
      end

      def self.show_tables_from_step(step)
        step.fetch("context", {}).fetch("tables", {}).each do |section, tbls|
          tbls.each { |name, tbl| show_table(section, name, tbl) }
        end
      end

      def check
        Support::Display.info("checking (reqs=#{@reqs.size})", "expectations")
        @reqs.each do |req_id, vals|
          step = @qcl.last_step_by_request(req_id)
          if step
            ac_tables = step.fetch('context', {}).fetch('tables', {})
            ex_tables = vals[:expected].fetch('tables', [])
            ex_tables.each do |section, ex_section_tables|
              ac_section_tables = ac_tables.fetch(section, {})
              ex_section_tables.each do |name, ex_tbl|
                ac_tbl = ac_section_tables.fetch(name, nil)
                if !ac_tbl
                  Support::Display.error("expected table to exist, but not found in results (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id}); tables=#{ac_section_tables.keys}")
                elsif ac_tbl.length != ex_tbl.length
                  Support::Display.error("expected table sizes to match (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id}; ac_len=#{ac_tbl.length}; ex_len=#{ex_tbl.length})")
                elsif ac_tbl != ex_tbl
                  Support::Display.error("expected tables to match (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
                  TableExpectations::show_table(section, name, ac_tbl, 'actual')
                  TableExpectations::show_table(section, name, ex_tbl, 'expected')
                else
                  TableExpectations::show_table(section, name, ac_tbl)
                  Support::Display.info_strong("tables matched (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
                end
              end
            end
          else
            Support::Display.error("failed to find last step (test=#{vals[:name]}; req_id=#{req_id})")
          end
        end
      end
    end

    no_commands do
      def enumerate_files_in(pn, pat)
        Dir.glob(pn.join(pat)).map { |fn| Pathname.new(fn) }
      end

      def load_profile(pn)
        profile = MultiJson.decode(IO.read("profiles/#{pn}.json"))
        Support::Display.info_stage("profile (#{pn})")
        profile.each do |section, vs|
          Support::Display.info("#{section}")
          vs.each do |k, v|
            Support::Display.info("  #{k}: #{v}")
          end
        end

        profile
      end

      def send_rules_and_tables(profile, path)
        ns = path.basename
        cl = Clients::Revisions.new(profile['revisions']['url'])

        Support::Display.info_stage("gathering rules")
        rules = enumerate_files_in(path, '*.rule').map do |fpn|
          name = fpn.basename('.rule').to_s
          Support::Display.give('sending rule', 'test', name: name)
          cl.add_rule(ns, name, fpn.to_s)

          parsed_rule = parse_rule(IO.read(fpn.to_s))
          ver = parsed_rule.fetch('meta', {}).fetch('version', '999.999.999')
          
          { ns: ns.to_s, name: name, version: ver }
        end

        Support::Display.info_stage("gathering tables")
        enumerate_files_in(path, '*.table').each do |fpn|
          name = fpn.basename('.table')
          data_fn = Pathname.new(fpn.dirname).join("#{name}.json").to_s
          Support::Display.give('sending table (with data)', 'test', name: name, data_fn: data_fn)
          cl.add_table(ns, name, fpn.to_s, data_fn)

          name.to_s
        end

        yield(rules)
      end

      def while_waiting_for_scheduled(profile, topic, items_fn = nil)
        scl = Clients::Schedule.new(profile['schedule']['url'])
        sel = SynchroEventsListener.new(
          profile['events']['url'],
          profile['events']['ws_url'],
          topic
        )

        sel.listen
        sel.wait_until_ready

        Support::Display.info_stage("making requests")
        req_ids = yield(scl)
        
        Support::Display.info_stage("waiting (topic=#{topic}, n_reqs=#{req_ids.length})")      
        sel.join(req_ids, items_fn)
      end
    end

    desc 'effective <path> <profile_name>', 'runs a test of effective rule matching'
    def effective(path_name, profile_name)
      profile = load_profile(profile_name)
      path = Pathname.new(path_name)
      
      expects = RuleExpectations.new(profile['query']['url'])

      send_rules_and_tables(profile, path) do |rules|
        expects.add_expected_rules(rules)
        items_fn = lambda do |items|
          expects.add_actual_rule_ids(items.map { |it| it[:rule_id] })
        end
        
        while_waiting_for_scheduled(profile, 'verification', items_fn) do |scl|
          rules.inject(Set.new) do |set, rule|
            verify_fn = path.join("#{rule[:name]}.verify_compute.json")
            eff = verify_fn.exist? ? JSON.parse(IO.read(verify_fn)) : {}

            Support::Display.give(
              'scheduling effective test', 'test', verify_fn: verify_fn.to_s
            )
            req_id = scl.verify_effective(eff.fetch("document", {}), eff.fetch("effective_contexts", []))

            set << req_id
          end
        end

        Support::Display.info_stage("checking")
        expects.check
      end
    end
    
    desc 'applicable <path> <profile_name>', 'runs a test of effective rule matching'
    def applicable(path_name, profile_name)
      profile = load_profile(profile_name)
      path = Pathname.new(path_name)
      
      expects = RuleExpectations.new(profile['query']['url'])

      send_rules_and_tables(profile, path) do |rules|
        expects.add_expected_rules(rules)
        items_fn = lambda do |items|
          expects.add_actual_rule_ids(items.map { |it| it[:rule_id] })
        end
        
        while_waiting_for_scheduled(profile, 'verification', items_fn) do |scl|
          rules.inject(Set.new) do |set, rule|
            qcl = Clients::Query.new(profile['query']['url'])
            verify_fn = path.join("#{rule[:name]}.verify_compute.json")
            eff = verify_fn.exist? ? JSON.parse(IO.read(verify_fn)) : {}

            full_rule = qcl.rule_by_ns_name_version(rule[:ns], rule[:name], rule[:version])
            rule_id = full_rule.fetch('public_id', nil)
            
            Support::Display.give(
              'scheduling applicable test', 'test', verify_fn: verify_fn.to_s
            )

            req_id = scl.verify_applicable(rule_id, eff.fetch("document", {}), eff.fetch("sections", {}))

            set << req_id
          end
        end

        Support::Display.info_stage("checking")
        expects.check
      end
    end
    
    desc 'exec <path_name> <profile_name>', 'Runs a simple execute loop, uploading unpackaged rules and tables to revisions directly'
    def exec(path_name, profile_name)
      profile = load_profile(profile_name)
      path = Pathname.new(path_name)

      expects = TableExpectations.new(profile['query']['url'])
      
      send_rules_and_tables(profile, path) do |rules|
        while_waiting_for_scheduled(profile, 'audit') do |scl|
          rules.inject(Set.new) do |set, rule|
            ctx_fn = path.join("#{rule[:name]}.context.json")
            Support::Display.give(
              'scheduling rule test', 'test', ns: rule[:ns], name: rule[:name], ver: rule[:version], ctx_fn: ctx_fn.to_s
            )
            ctx = ctx_fn.exist? ? JSON.parse(IO.read(ctx_fn)) : {}
            req_id = scl.execute(rule[:ns], rule[:name], rule[:version], ctx)

            expects.add(req_id, rule[:name], path.join("#{rule[:name]}.expected.json"))

            set << req_id
          end
        end

        Support::Display.info_stage("checking")
        expects.check
      end
    end
  end
end
