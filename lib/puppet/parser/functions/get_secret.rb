# Copyright (c) 2010 (mt) Media Temple Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
Puppet::Parser::Functions::newfunction(:get_secret, :type => :rvalue) do |vals|
  modulename = vals[0]
  identifier = vals[1]
  default    = vals[2]

  # identifier can be a path and key delimited by a colon
  # the default path is 'main'.  examples:
  #  foo/bar:baz - looks in foo/bar.yml for key baz
  #  main:baz    - looks in main.yml for key baz
  #  baz         - looks in main.yml for key baz
  path, key = identifier.split(/:/)
  if key.nil?
    key = path
    path = 'main'
  end

  # check /etc/puppet/master.yml to see what environment we're in
  environment = Puppet[:environment]
  sec_path = 'secrets'

  # look for the module in each directory in modulepath
  paths = Puppet::Module.modulepath(Puppet[:environment]).map do |dir|
    "#{dir}/#{modulename}/#{sec_path}/#{path}.yml"
  end

  values = paths.map do |module_secret_file|
    # and see if it has a secret .yml file
    if File.exists?(module_secret_file)
      get_secret_get_value(module_secret_file, modulename, key)
    end
  end

  # filter out nil values
  values = values.select { |val| !val.nil? }

  # pull the first if there are any values left
  return get_clear_text_value(values[0]) if !values.empty?
  
  if !default
    raise Puppet::ParseError, "Unable to find secret value for module #{modulename} and key #{identifier}, tried #{report_path}"
  else
    return default
  end
end

# Just call out to get_var_get_value as the logic is the same now
def get_secret_get_value (yaml_file, modulename, identifier)
  get_var_get_value(yaml_file, modulename, identifier)
end

def get_clear_text_value (cipher_text)
  clear_text = `echo '#{cipher_text}' | base64 -d | gpg -dq`
  clear_text.strip
end
