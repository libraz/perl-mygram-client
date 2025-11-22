#!/usr/bin/env perl

use strict;
use warnings;
use MygramDB::Client;

# Create client
my $client = MygramDB::Client->new(
    host    => 'localhost',
    port    => 11016,
    timeout => 5,
);

# Connect
$client->connect() or die "Connection failed: " . $client->errstr;

print "Connected to MygramDB\n";

# Get server info
my $info = $client->info();
if ($info) {
    print "Server info:\n";
    print $info->{raw}, "\n";
} else {
    warn "Failed to get info: " . $client->errstr . "\n";
}

# Search
print "\n=== Simple Search ===\n";
my $result = $client->search(
    table => 'articles',
    query => 'hello',
    limit => 10,
);

if ($result) {
    print "Found: $result->{total_count} results\n";
    print "Showing ", scalar(@{$result->{results}}), " results:\n";

    for my $doc (@{$result->{results}}) {
        print "  - $doc->{primary_key}\n";
    }
} else {
    warn "Search failed: " . $client->errstr . "\n";
}

# Advanced search with filters
print "\n=== Advanced Search ===\n";
$result = $client->search(
    table       => 'articles',
    query       => 'tech',
    limit       => 10,
    and_terms   => ['AI'],
    not_terms   => ['old'],
    filters     => { status => 1 },
    sort_column => 'created_at',
    sort_desc   => 1,
);

if ($result) {
    print "Found: $result->{total_count} results (with filters)\n";
} else {
    warn "Advanced search failed: " . $client->errstr . "\n";
}

# Count
print "\n=== Count ===\n";
my $count = $client->count(
    table => 'articles',
    query => 'hello',
);

if (defined $count) {
    print "Total matches: $count\n";
} else {
    warn "Count failed: " . $client->errstr . "\n";
}

# Get document
print "\n=== Get Document ===\n";
my $doc = $client->get(
    table       => 'articles',
    primary_key => '1',
);

if ($doc) {
    print "Document: $doc->{primary_key}\n";
    print "Fields:\n";
    for my $key (sort keys %{$doc->{fields}}) {
        print "  $key = $doc->{fields}{$key}\n";
    }
} else {
    warn "Get failed: " . $client->errstr . "\n";
}

# Disconnect
$client->disconnect();
print "\nDisconnected\n";
