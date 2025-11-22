#!/usr/bin/env perl

use strict;
use warnings;

# Try to load XS module
eval { require MygramDB::Client::XS; };

if ($@) {
    die "MygramDB::Client::XS is not available.\n" .
        "Please build the XS module first.\n" .
        "Error: $@\n";
}

# Create client
my $client = MygramDB::Client::XS->new(
    'localhost',  # host
    11016,        # port
    5000,         # timeout_ms
    65536,        # recv_buffer_size
);

print "Created XS client\n";

# Connect
eval { $client->connect() };
if ($@) {
    die "Connection failed: $@\n";
}

print "Connected to MygramDB (XS)\n";

# Get server info
eval {
    my $info = $client->info();
    print "Server info:\n";
    print "  Version: $info->{version}\n";
    print "  Uptime: $info->{uptime_seconds}s\n";
    print "  Documents: $info->{doc_count}\n";
    print "  Tables: ", join(", ", @{$info->{tables}}), "\n";
};
if ($@) {
    warn "Failed to get info: $@\n";
}

# Simple search
print "\n=== Simple Search (XS) ===\n";
eval {
    my $result = $client->search(
        'articles',  # table
        'hello',     # query
        10,          # limit
        0,           # offset
    );

    print "Found: $result->{total_count} results\n";
    for my $doc (@{$result->{results}}) {
        print "  - $doc->{primary_key}\n";
    }
};
if ($@) {
    warn "Search failed: $@\n";
}

# Advanced search
print "\n=== Advanced Search (XS) ===\n";
eval {
    my $result = $client->search_advanced(
        'articles',       # table
        'technology',     # query
        50,               # limit
        0,                # offset
        ['AI'],           # AND terms
        ['old'],          # NOT terms
        {status => 1},    # filters
        'created_at',     # sort column
        1,                # sort descending
    );

    print "Found: $result->{total_count} results (with filters)\n";
};
if ($@) {
    warn "Advanced search failed: $@\n";
}

# Count
print "\n=== Count (XS) ===\n";
eval {
    my $count = $client->count('articles', 'hello');
    print "Total matches: $count\n";
};
if ($@) {
    warn "Count failed: $@\n";
}

# Get document
print "\n=== Get Document (XS) ===\n";
eval {
    my $doc = $client->get('articles', '1');
    print "Document: $doc->{primary_key}\n";
    print "Fields:\n";
    for my $key (sort keys %{$doc->{fields}}) {
        print "  $key = $doc->{fields}{$key}\n";
    }
};
if ($@) {
    warn "Get failed: $@\n";
}

# Disconnect
$client->disconnect();
print "\nDisconnected\n";
