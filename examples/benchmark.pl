#!/usr/bin/env perl

use strict;
use warnings;
use Time::HiRes qw(time);
use MygramDB::Client;

# Try to load XS module
my $has_xs = eval { require MygramDB::Client::XS; 1 };

print "MygramDB Client Benchmark\n";
print "=" x 50, "\n\n";

# Configuration
my $host = 'localhost';
my $port = 11016;
my $iterations = 100;

# Create Pure Perl client
my $pp_client = MygramDB::Client->new(
    host    => $host,
    port    => $port,
    timeout => 5,
);

$pp_client->connect() or die "Failed to connect (Pure Perl): " . $pp_client->errstr;
print "Pure Perl client connected\n";

# Benchmark Pure Perl search
my $pp_start = time;
for (1..$iterations) {
    my $result = $pp_client->search(
        table => 'articles',
        query => 'test',
        limit => 100,
    );
}
my $pp_elapsed = time - $pp_start;
my $pp_avg = $pp_elapsed / $iterations;

print "Pure Perl: $iterations searches in ${pp_elapsed}s (avg: ${pp_avg}s)\n";

$pp_client->disconnect();

# Benchmark XS if available
if ($has_xs) {
    print "\n";

    my $xs_client = MygramDB::Client::XS->new($host, $port, 5000, 65536);
    eval { $xs_client->connect() };

    if ($@) {
        warn "Failed to connect (XS): $@\n";
    } else {
        print "XS client connected\n";

        my $xs_start = time;
        for (1..$iterations) {
            eval {
                my $result = $xs_client->search('articles', 'test', 100, 0);
            };
        }
        my $xs_elapsed = time - $xs_start;
        my $xs_avg = $xs_elapsed / $iterations;

        print "XS: $iterations searches in ${xs_elapsed}s (avg: ${xs_avg}s)\n";

        $xs_client->disconnect();

        # Calculate speedup
        my $speedup = $pp_elapsed / $xs_elapsed;
        printf("\nXS is %.2fx faster than Pure Perl\n", $speedup);
    }
} else {
    print "\nXS module not available - skipping XS benchmark\n";
}

print "\nBenchmark complete\n";
