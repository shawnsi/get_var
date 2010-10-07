# Overview

# The *get_var* function

The *get_var* function's purpose is threefold:

* Use production and development data where appropriate
* Not have passwords and other secret bits in subversion/git/whatever
* Manage multiple similar configurations (same manifest, different systems)

## Puppet code examples

The main interface from puppet is the *get_var* function.  There are two required parameters to the *get_var* function, and one optional parameter.

    $variable = get_var("module", "key to look up")

The first parameter is which puppet module to examine for the requested data.  Data should be kept in the module where it's most used or most authoritative.

The second parameter is the key to look up in that module.  It can contain periods to drill down into the YAML structure.  For instance:

Looking up "name" in this YAML would return "puppetmaster":

    name: puppetmaster

Looking up "nate.shell" in this YAML would return "bash":

    nate:
      shell: bash

If the key ends with the word "keys", an attempt will be made to read the keys at that level in the YAML file.  For instance, given the following YAML:

    var1:
      value1
    var2:
      value2
    var3:
      value3

Calling looking up the key 'keys' will return an array of strings: `["var1", "var2", "var3"]`.

The third parameter contains an optional default value.  If this is passed in, and *get_var* is unable to find a value for the key you specified, it will return this default instead of throwing an error.

The optional value should only be used for true defaults, not development values.  Any value that should exist in a development environment should be in the development YAML files, so that it can be properly overridden or looked up as needed.

## YAML file locations

Both production and development data are stored in the puppet module itself.  Production data goes in the `var/` subdirectory and development data goes in the `var_dev/` subdirectory.  Other than that, the following conventions apply to both sets of data.

If the look up key doesn't have a colon (':'), then the YAML file is main.yml.  So the following lookup:

    get_var('module', 'foo')

will look for the 'foo' key in the `module/*var*/main.yml` file in production and the `module/*var_dev*/main.yml` file in development.

If the key does have a colon, the part before the colon is treated as a filename.  It can contain slashes to add heirarchy to the data.  For example, the following lookup:

    get_var('module', 'bar/baz:foo')

will look for the 'foo' key in the `module/*var*/bar/baz.yml` file in production and the `module/*var_dev*/bar/baz.yml` file in development.

### Development overrides

When running in development mode, *get_var* will look in `/etc/puppet/var_dev` for files that override development values.  So, in the above lookup (for 'bar/baz:foo'), the file `/etc/puppet/var_dev/module/bar/baz.yml` will be checked before `module/var_dev/bar/baz.yml` in development mode.

This directory is completely ignored in production mode.

# The *get_secret* function

The *get_secret* function is nearly identical to the *get_var* function, except it's designed for managing data that we'd like to keep a secret.  This includes passwords, ssh private keys, and ssl certificates, among other things.

## Puppet code examples

The primary interface is the *get_secret* function.  Like *get_var*, *get_secret* has two required parameters and one optional parameter.

    $variable = get_secret("module", "key to look up")

The parameters are identical to what *get_var* expects.

## YAML file locations

Development secret data is stored in the puppet module itself in the `secret_dev/` subdirectory.  Production secret data is stored in `/etc/puppet/secret` on the puppet master.

Like *get_var*, if the key doesn't have a colon (':'), then the YAML file is main.yml.  So, the following lookup:

    get_secret('module', 'foo')

will look for the 'foo' key in the `*/etc/puppet/secret*/module/main.yml` file in production and the `module/*secret_dev*/main.yml` file in development.

And, like *get_var* if the key has a colon, the part before the colon is treated as a filename.

# Configuration

Both *get_var* and *get_secret* inspect the same file to figure out which mode they are in (development or production).  The file is `/etc/puppet/master.yml`.  The file contains only one key: `environment`.  The value is either "development" or "production".  If the file doesn't exist, "development" is assumed.

    environment: production

# Tips

## Sample puppet module

There is a example puppet module in the `get_example` subdirectory.

## Generating YAML file with multi-line values

Write up a perl script like this:

    #!/usr/bin/perl

    use strict;
    use warnings;
    use YAML qw(Dump);

    my $key = <<KEY;
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam auctor dapibus
    eros, nec gravida metus posuere vulputate. Mauris a tortor non ligula gravida
    fringilla. Nullam sed risus ac dolor gravida bibendum. Pellentesque a lectus id
    risus faucibus laoreet quis vitae lacus. Suspendisse scelerisque feugiat
    ligula, id pretium neque dictum non.
    KEY

    print Dump({key => $key});

Running that code will generate the YAML you want:

    ---
    key: |
      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam auctor dapibus
      eros, nec gravida metus posuere vulputate. Mauris a tortor non ligula gravida
      fringilla. Nullam sed risus ac dolor gravida bibendum. Pellentesque a lectus id
      risus faucibus laoreet quis vitae lacus. Suspendisse scelerisque feugiat
      ligula, id pretium neque dictum non.

# Copyright

    Copyright (c) 2010 (mt) Media Temple Inc.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
