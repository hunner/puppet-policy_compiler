require 'puppet/indirector/catalog/compiler'

require 'rspec'
require 'rspec-puppet/errors'
require 'rspec-puppet/matchers'

## RSpec catalog helper module to provide `subject` method for specs
module RSpec::Puppet::CatalogExampleGroup
  include RSpec::Puppet::ManifestMatchers

  def subject
    RSpec.configuration.catalog
  end

  def facts
    RSpec.configuration.facts
  end
end

class Puppet::Resource::Catalog::PolicyCompiler < Puppet::Resource::Catalog::Compiler
  desc "Puppet's catalog policy enforcement compiler"

  def find(request)
    ## Call normal catalog compiler and grab the facts
    catalog = super
    facts = extract_facts_from_request(request)

    ## Check policy failures and return catalog if there were no failures
    if (failed_policies = policy_check(catalog, facts)).empty?
      catalog
    else
      raise Puppet::Error, "Catalog failed to pass security policies:\n" + failed_policies.join("\n")
    end
  end

  def policy_check(catalog, facts)
    ## Configure RSpec with catalog spec helper and compiled catalog data
    RSpec.configuration.color = true
    RSpec.configure do |c|
      c.add_formatter(:progress)
      c.add_formatter(:json)
      c.add_setting :catalog, :default => catalog
      c.add_setting :facts,   :default => facts
      c.backtrace_clean_patterns = [
        /\/puppet\/(lib|bin)\//,
        /\/ruby\//,
      ]
      c.include RSpec::Puppet::CatalogExampleGroup
      c.extend  RSpec::Puppet::CatalogExampleGroup
    end

    ## Configure JSON RSpec reporting formatter
    config = RSpec.configuration
    progress_formatter = RSpec::Core::Formatters::ProgressFormatter.new($stdout)
    json_formatter = RSpec::Core::Formatters::JsonFormatter.new(config.out)
    reporter  = RSpec::Core::Reporter.new(progress_formatter, json_formatter)
    config.instance_variable_set(:@reporter, reporter)

    ## Run RSpec on the policies directory
    Puppet.info("Performing policy rspec-puppet checks")
    RSpec::Core::Runner.run(["#{Puppet[:confdir]}/policies"])

    ## Return an array of failed policy descriptions
    json_formatter.output_hash[:examples].collect do |policy|
      "-- Failed policy: #{policy[:exception][:message]}" if policy[:status] == 'failed'
    end.compact
  end
end
