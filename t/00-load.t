#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok('MygramDB::Client') || print "Bail out!\n";
}

diag("Testing MygramDB::Client $MygramDB::Client::VERSION, Perl $], $^X");
