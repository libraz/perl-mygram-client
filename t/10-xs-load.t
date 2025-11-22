#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# XS module is optional
eval { require MygramDB::Client::XS; };

if ($@) {
    plan skip_all => 'MygramDB::Client::XS not available (XS module not built)';
} else {
    plan tests => 2;
    use_ok('MygramDB::Client::XS');
    diag("Testing MygramDB::Client::XS $MygramDB::Client::XS::VERSION");

    # Test constructor
    my $client = MygramDB::Client::XS->new('localhost', 11016, 5000, 65536);
    isa_ok($client, 'MygramDB::Client::XS', 'XS client object');
}
