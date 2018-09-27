require_relative '../support/simple_migration'

class Repos < Support::SimpleMigration
  def self.statements
    [
      'CREATE TABLE interlibr.repositories (clone_url text, PRIMARY KEY (clone_url))',
    ]
  end
end
