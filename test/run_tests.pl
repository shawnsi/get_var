#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);

# test script;
use Test::More;
use File::Slurp;

if ( shift ne '-y' ) {
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

# remove all test outputs
`rm -f /tmp/get_var-*`;
`rm -rf /etc/puppet/var_dev/get_var`;
set_environment();

my @tests = (
    {   count => 2,
        code  => sub {
            my $t = 'dev secret fetch works';

            set_environment();

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_secret("get_var", "password")
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
include "get_var"

$foo = get_secret("get_var", "password")
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

            `mkdir -p /etc/puppet/secret/get_var`;
            `echo "password: prodsecretvalue" > /etc/puppet/secret/get_var/main.yml`;
            set_environment('production');

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_secret("get_var", "password")
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
include "get_var"

$var = 3
$foo = get_var("get_var", "${var}key")
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
include "get_var"

$foo = get_var("get_var", "key")
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

            `mkdir -p /etc/puppet/var_dev/get_var`;
            `echo "key: overridevalue" > /etc/puppet/var_dev/get_var/main.yml`;

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "key")
file { "/tmp/get_var-dev1.txt":
    content => $foo
}
PUPPET

            my $contents = read_file('/tmp/get_var-dev1.txt');
            is( $contents, 'overridevalue', $t );
            is( $rc, 0, $t );

            `rm -rf /etc/puppet/var_dev/get_var`;
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'prod value fetch works';

            set_environment('production');

            my ( $rc, $ouput ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "key")
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
include "get_var"

$foo = get_var("get_var", "multikey")
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
include "get_var"

$foo = get_var("get_var", "keys")
file { "/tmp/get_var-dev3.txt":
    content => "$foo"
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev3.txt');
        is( $contents, 'domain.comhash3keydomainmultikeykey', $t );
    },
    sub {
        my $t = 'keys';

        set_environment();

        run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "hash.keys")
file { "/tmp/get_var-dev4.txt":
    content => "$foo"
}
PUPPET

        my $contents = read_file('/tmp/get_var-dev4.txt');
        is( $contents, 'key3key1key2', $t );
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var default';

            set_environment();

            my ($rc) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "noexist", "default")
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
include "get_var"

$foo = get_var("get_var", "noexist")
PUPPET

            is( $rc, 1, $t );
            ok( $output
                    =~ /Unable to find var for noexist in module get_var/,
                "$t - error"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var missing complex value';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "noexist.foo.bar")
PUPPET

            is( $rc, 1, $t );
            ok( $output
                    =~ /Unable to find var for noexist.foo.bar in module get_var/,
                "$t - error"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'get_var periods in keys';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_var("get_var", "domain.com.key")
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
include "get_var"

$foo = get_var("get_var", "domain.domain.com.key")
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
            my $t = 'get_secret key shown in error message';

            set_environment();

            my ( $rc, $output ) = run_puppet(<<'PUPPET');
include "get_var"

$foo = get_secret("get_var", "noexist")
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
include "get_var"

$foo = get_secret("get_var", "noexist")
PUPPET

            is( $rc, 1, $t );
            ok( $output =~ /and key noexist/, "$t - error" );
            `rm -rf /etc/puppet/secret`;
            }
    },
);

our $tests += ( ref($_) eq 'HASH' ? $_->{count} : 1 ) for @tests;
plan tests => $tests;

( ref($_) eq 'HASH' ? $_->{code}->() : $_->() ) for @tests;

sub run_puppet {
    my $code = shift;

    write_file( 'manifest.pp', $code );
    my $output = `./run_test.sh manifest.pp 2>&1`;
    my $rc     = $? >> 8;

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
