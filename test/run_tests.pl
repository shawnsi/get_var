#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use Cwd qw/ abs_path getcwd /;
use File::Temp qw/ tempdir cleanup /;
use File::Basename;

# test script;
use Test::More;
use File::Slurp;

# Make sure we are in the 'test' directory.
chdir( dirname( abs_path( $0 ) ) );

# We put our temp dirs at the begining of our module path so that we
# decrease the risk of leaving cruft behind...
my @modulepath = (
    tempdir( getcwd() . "/pathXXXX", CLEANUP => 1 ) ,
    tempdir( getcwd() . "/pathXXXX", CLEANUP => 1 ) ,
    abs_path( getcwd() . "/../../" ),
    abs_path( getcwd() ),
);

if ( ! scalar( @ARGV ) or shift ne '-y' ) {
    print <<WARNING;
===========================================================================
This will mess with /etc/puppet/secret and /etc/puppet/var_dev!!
Press enter if you are OK with this.  Pass '-y' to this script if you don't
need this warning.
===========================================================================
WARNING
    <STDIN>;
}

chdir $Bin;

# remove all test output
clean_all_test_output();

my @tests = (
    {   count => 2,
        code  => sub {
            my $t = 'dev secret fetch works';

            set_environment();

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_secret("test_module", "password")
file { "/tmp/get_var-secret1.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_var-secret1.txt');
            is( $contents, 'devsecretvalue', $t );
            }
    },
    {   count => 1,
        code  => sub {
            my $t = 'prod secret fetch fails if no secrets';

            `rm -rf /etc/puppet/secret`;
            set_environment('production');

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_secret("test_module", "password")
file { "/tmp/get_var-secret1.txt":
    content => $foo
}
PUPPET

            is( $rc, 1, $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'prod secret works';

            `mkdir -p /etc/puppet/secret/test_module`;
            `echo "password: prodsecretvalue" > /etc/puppet/secret/test_module/main.yml`;
            set_environment('production');

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_secret("test_module", "password")
file { "/tmp/get_var-secret1.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_var-secret1.txt');
            is( $contents, 'prodsecretvalue', $t );

            `rm -rf /etc/puppet/secret`;
            }
    },
    sub {
        my $t = 'numeric value fetch works';

        set_environment();

        run_puppet(<<'PUPPET');
include "test_module"

$var = 3
$foo = get_var("test_module", "${var}key")
notice($foo)
file { "/tmp/get_var-dev6.txt":
    content => $foo
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev6.txt');
        is( $contents, 'numbervalue', $t );
    },
    sub {
        my $t = 'dev value fetch works';

        set_environment();

        run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "key")
file { "/tmp/get_var-dev1.txt":
    content => $foo
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev1.txt');
        is( $contents, 'devvalue', $t );
    },
    {   count => 2,
        code  => sub {
            my $t = 'local dev override';

            set_environment();

            `mkdir -p /etc/puppet/var_dev/test_module`;
            `echo "key: overridevalue" > /etc/puppet/var_dev/test_module/main.yml`;

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "key")
file { "/tmp/get_var-dev1.txt":
    content => $foo
}
PUPPET

            my $contents = read_file('/tmp/get_var-dev1.txt');
            is( $contents, 'overridevalue', $t );
            is( $rc, 0, $t );

            `rm -rf /etc/puppet/var_dev/test_module`;
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'prod value fetch works';

            set_environment('production');

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "key")
file { "/tmp/get_var-dev1.txt":
    content => $foo
}
PUPPET

            my $contents = read_file('/tmp/get_var-dev1.txt');
            is( $contents, 'prodvalue', $t );
            is( $rc,       0,           $t );
            }
    },

    sub {
        my $t = 'dev value (long) fetch works';

        set_environment();

        run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "multikey")
file { "/tmp/get_var-dev2.txt":
    content => $foo
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev2.txt');
        is( $contents, <<LONG, $t );
Lorem Ipsum is simply dummy text of the printing and typesetting industry.
Lorem Ipsum has been the industry's standard dummy text ever since the 1500s,
when an unknown printer took a galley of type and scrambled it to make a type
specimen book. It has survived not only five centuries, but also the leap into
electronic typesetting, remaining essentially unchanged. It was popularised in
the 1960s with the release of Letraset sheets containing Lorem Ipsum passages,
and more recently with desktop publishing software like Aldus PageMaker
including versions of Lorem Ipsum.
LONG
    },
    sub {
        my $t = 'keys (at root)';

        set_environment();

        run_puppet(<<'PUPPET');
include "test_module"

$array = get_var("test_module", "keys")
$foo = inline_template('<%= array.join("|") %>')
file { "/tmp/get_var-dev3.txt":
    content => "$foo"
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev3.txt');
        is( $contents, 'domain.com|domain2|hash|3key|domain|multikey|key', $t );
    },
    sub {
        my $t = 'keys';

        set_environment();

        run_puppet(<<'PUPPET');
include "test_module"

$array = get_var("test_module", "hash.keys")
$foo = inline_template('<%= array.join("|") %>')
file { "/tmp/get_var-dev4.txt":
    content => "$foo"
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev4.txt');
        is( $contents, 'key3|key1|key2', $t );
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var default';

            set_environment();

            my ($rc) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "noexist", "default")
file { "/tmp/get_var-dev5.txt":
    content => $foo
}
PUPPET

            my $contents = read_file('/tmp/get_var-dev5.txt');
            is( $contents, 'default', $t );
            is( $rc,       0,         $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var missing value';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "noexist")
PUPPET

            is( $rc, 1, $t );
            ok( $output
                    =~ /Unable to find var for noexist in module test_module/,
                "$t - error"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var missing complex value';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "noexist.foo.bar")
PUPPET

            is( $rc, 1, $t );
            ok( $output
                    =~ /Unable to find var for noexist.foo.bar in module test_module/,
                "$t - error"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var periods in keys';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "domain.com.key")
file { "/tmp/get_var-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_var-dev3.txt');
            is( $contents, 'domain_key', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var periods in keys 2';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_var("test_module", "domain.domain.com.key")
file { "/tmp/get_var-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_var-dev3.txt');
            is( $contents, 'lower_domain_key', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var periods in keys 3 (looks like domain but is not)';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
$foo = get_var("test_module", "domain2.com.key")
file { "/tmp/get_var-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_var-dev3.txt');
            is( $contents, 'heirarchical_key', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_secret periods in keys';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
$foo = get_secret("test_module", "domain.com.key")
file { "/tmp/get_secret-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_secret-dev3.txt');
            is( $contents, 'domain_secret', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_secret periods in keys 2';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
$foo = get_secret("test_module", "domain.domain.com.key")
file { "/tmp/get_secret-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_secret-dev3.txt');
            is( $contents, 'lower_domain_secret', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_secret periods in keys 3 (looks like domain but is not)';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
$foo = get_secret("test_module", "domain2.com.key")
file { "/tmp/get_secret-dev3.txt":
    content => $foo
}
PUPPET

            is( $rc, 0, $t );
            my $contents = read_file('/tmp/get_secret-dev3.txt');
            is( $contents, 'heirarchical_secret', $t );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_secret key shown in error message';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_secret("test_module", "noexist")
PUPPET

            is( $rc, 1, $t );
            ok( $output =~ /and key noexist/, "$t - error" );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'prod get_secret key shown in error message';

            `mkdir -p /etc/puppet/secret/get_var`;
            `echo "password: prodsecretvalue" > /etc/puppet/secret/get_var/main.yml`;
            set_environment('production');

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "test_module"

$foo = get_secret("test_module", "noexist")
PUPPET

            is( $rc, 1, $t );
            ok( $output =~ /and key noexist/, "$t - error" );
            `rm -rf /etc/puppet/secret`;
            }
    },
    {   count => 8,
        code  => sub {
            my $t = 'precedence follows modulepath order';
            my $module = "test_module_test";

            set_environment('production');

            foreach ( @modulepath ) {
                my $dir = $_;
                my $module_dir = $dir . "/" . $module;

                # Create the top level dir if needed and them the module dir
                # and finally our var dir.
                mkdir( $module_dir ) or die( $! );
                mkdir( "$module_dir/var" ) or die ( $! );
                
                # Create our var yaml file.
                `echo "path: $dir" > "$module_dir/var/main.yml"`;
            }

            foreach ( @modulepath ) {
                my $dir = $_;
                my $module_dir = $dir . "/" . $module;

                my ( $rc, $output ) = run_puppet(<<PUPPET);
\$path = get_var( "$module", "path")
notice("### found value in \$path ###")
PUPPET

                is( $rc, 0, $t );
                ok( $output =~ /### found value in $dir ###/, "$t - $dir" );
                
                # Cleanup our mess.
                unlink( "$module_dir/var/main.yml" ) or dir( $! );
                rmdir( "$module_dir/var" );
                rmdir( $module_dir );
            }
        }
    },
);

our $tests += ( ref($_) eq 'HASH' ? $_->{count} : 1 ) for @tests;
plan tests => $tests;

( ref($_) eq 'HASH' ? $_->{code}->() : $_->() ) for @tests;

# remove all test output
clean_all_test_output();

exit;

sub run_puppet {
    my $code = shift;

    write_file( 'manifest.pp', $code );

    my $command = 'puppet -d --modulepath=' . join( ":", @modulepath ) . ' manifest.pp 2>&1';
    my $output  = `$command`;
    my $rc      = $? >> 8;

    #diag($output);

    return ( $rc, $output );
}

sub set_environment {
    my $env = shift;

    if ($env) {
        `mkdir -p /etc/puppet`;
        `echo "environment: $env" > /etc/puppet/master.yml`;
    }
    else {
        `rm -f /etc/puppet/master.yml`;
    }
}

sub clean_all_test_output {
    `rm -f /tmp/get_var-*`;
    `rm -rf /etc/puppet/var_dev/test_module`;
    set_environment();
}
