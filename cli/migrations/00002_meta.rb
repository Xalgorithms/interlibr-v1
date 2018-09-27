require_relative '../support/simple_migration'

# The key for this table is very specific to the queries we
# make. Since we use the origin, branch to find rule_ids, the rule_id
# CANNOT be the primary key
# https://www.datastax.com/dev/blog/a-deep-look-to-the-cql-where-clause
#
# Additional tables will need to be made for additional queries
class Meta < Support::SimpleMigration
  def self.statements
    [
      'CREATE TABLE interlibr.rules (rule_id text, origin text, branch text, ns text, name text, version text, runtime text, criticality text, PRIMARY KEY (origin, branch, rule_id))',
      'CREATE TABLE interlibr.rules_origin_and_branch (rule_id text, origin text, branch text, PRIMARY KEY (rule_id, origin, branch))',
    ]
  end
end
