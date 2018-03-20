module Support
  class SimpleMigration
    def self.up(cl)
      cl.execute(statements)
    end
  end
end
