require_relative '../support/simple_migration'

class Rulerefs < Support::SimpleMigration
  def self.statements
    [
      'CREATE TABLE interlibr.rules_in_use (rule_id text, refs counter, PRIMARY KEY (rule_id))',
    ]
  end
end
