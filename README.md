policy\_compiler
================

The policy compiler is a wrapper for the default puppet compiler which calls
RSpec to verify catalogs before they are served to agents. Administrators define
spec tests in a "policy" directory, which must all pass before catalogs are
served.

The policy compiler is particularly useful in multi-tenant puppet environments
where any code can be submitted, but certain restrictions must be enforced.

Example video: https://drive.google.com/file/d/0B5kb2EwzUaWrSVlkbDZzOTJjVUE/

Requirements
------------

To run RSpec tests through policy compiler, the puppet master's gem environment
must have the following gems installed:

  - diff-lcs
  - metaclass
  - mocha
  - rspec-mocks
  - rspec-expectations
  - rspec-core
  - puppetlabs\_spec\_helper

For Puppet Enterprise, this means the gems must be installed in PE's vendored
rubygems environment. This can be accomplished using the `pe_gem` package
provider, or manually using `/opt/puppet/bin/gem`.

Installation
------------

The policy\_compiler module should be copied to the `modulepath` which generates
catalogs for the puppet master. Pluginsync will ensure it is installed at the
master's next puppet run.

Next, routes.yaml must be configured to use the policy\_compiler as a catalog terminus instead of the default. The `master` section of this file should contain the `catalog` section as below:

```yaml
# /etc/puppetlabs/puppet/routes.yaml
master:
      catalog:
        terminus: policy_compiler
```

Finally, the `policy` directory must exist in the puppet master's `$confdir`.
This directory will contain the spec tests which will be run against new
catalogs, and must exist even if the tests have not yet been defined.

Configuration
-------------

TBD. Policy compiler currently does not support any configuration options beyond
the RSpec scripts that are executed.

How it works
------------

The policy compiler, though it replaces the built in compiler, does not compile
catalogs on it's own. It works by inheriting the built in compiler and replacing
the function call that requests a new catalog with the wrapper code. The process
essentially looks like this:

  When a catalog is requested:
  1. Call the built in compiler
  2. Extract all facter data from the compiled catalog
  3. Pass the catalog to RSpec along with a `facts` hash with all facts
  4. Call every *_spec.rb file in `$confdir/policies`
  5. Fail the catalog if any of the tests fail

Writing tests
-------------

All files in `$confidir/policies` that end with `_spec.rb` will be executed by
the policy compiler. Any Ruby, RSpec, or rspec-puppet code is valid in these
files.

Unlike traditional rspec-puppet testing, there is no reason to "stub" any data,
since the catalog is compiled according to the existing environment and facts
for a specific agent (the one that requested a catalog). Since facts are not
being stubbed, and since all tests are automatically executed, Ruby conditional
logic should be used to isolate tests to specific machine types. For example:

```ruby
# security_spec.rb

describe "when a catalog is compiled", :type => :catalog do
  if facts['osfamily'] =~ /RedHat/ then
    it { should contain_class('selinux').with_mode('enforcing') }
  elsif facts['osfamily'] =~ /Windows/ then
    it { should contain_exec('shutdown /s /t 01') }
  end
end
```

