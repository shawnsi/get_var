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
  environment = get_secret_find_environment()

  if environment == 'production'
    secret_directory = '/etc/puppet/secret'
    if (File.directory?(secret_directory))
      yaml_file = "#{secret_directory}/#{modulename}/#{path}.yml"
      value = get_secret_get_value(yaml_file, modulename, key)

      if value
        return value
      elsif default
        return default
      else
        raise Puppet::ParseError, "Unable to find secret value for module #{modulename} and key #{identifier}, tried #{yaml_file}"
      end
    else
      raise Puppet::ParseError, "puppet is in production mode, but production secrets (#{secret_directory}) aren't found"
    end
  else
    # look for the module in each directory in modulepath
    values = Puppet::Module.modulepath(Puppet[:environment]).map do |dir|
      # and see if it has a secret.yml file
      module_secret_file = "#{dir}/#{modulename}/secret_dev/#{path}.yml"
      if File.exists?(module_secret_file)
        get_secret_get_value(module_secret_file, modulename, key)
      end
    end

    # filter out nil values
    values = values.select { |val| !val.nil? }

    # pull the first if there are any values left
    return values[0] if !values.empty?
  end
  
  if !default
    if environment == 'production'
      report_path = yaml_file
    else
      report_path = "secret_dev/#{path}.yml"
    end
    raise Puppet::ParseError, "Unable to find secret value for module #{modulename} and key #{identifier}, tried #{report_path}"
  else
    return default
  end
end

# these functions are used here and in get_var.rb
def get_secret_find_environment ()
  conf_file = '/etc/puppet/master.yml'
  if (File.exists?(conf_file))
    conf = YAML.load_file(conf_file)
    if (conf['environment'])
      return conf['environment']
    end
  end

  return 'development'
end

def get_secret_get_value (yaml_file, modulename, identifier)
    if File.exists?(yaml_file)
      begin
        value = get_secret_drill_down(YAML.load_file(yaml_file), identifier.split(/\./))
        if value
          return value
        else
          return nil
        end
      rescue Puppet::ParseError => e
        raise e
      rescue Exception => e
        raise Puppet::ParseError, "Unable to parse secret yml file for module #{modulename}, tried #{yaml_file}: #{e}"
      end
    else
      return nil
    end
end

def get_secret_drill_down (data, ids)
  return nil unless data

  if (ids.length == 1)
    if (ids[0] == 'keys')
      return data.keys
    else
      return data[ids[0]]
    end
  else
    get_secret_drill_down(data[ids[0]], ids[1..-1])
  end
end
