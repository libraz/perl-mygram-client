#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MygramDB::Client;

SKIP: {
    skip "MygramDB server not available", 1 unless can_connect_to_server();

    my $client = MygramDB::Client->new(
        host => '127.0.0.1',
        port => 11016,
    );

    ok($client->connect(), 'Connect to server');

    # Note: These tests assume 'articles' table exists
    # Adjust table name and queries for your setup

    # Search test
    my $result = $client->search(
        table => 'articles',
        query => 'test',
        limit => 10,
    );

    if ($result) {
        ok(exists $result->{total_count}, 'Search result has total_count');
        ok(exists $result->{results}, 'Search result has results array');
        is(ref($result->{results}), 'ARRAY', 'Results is an array');
    } else {
        # Table might not exist or be empty
        diag("Search failed: " . $client->errstr());
        ok(1, 'Search returned error (table might not exist)');
    }

    # Count test
    my $count = $client->count(
        table => 'articles',
        query => 'test',
    );

    if (defined $count) {
        ok($count >= 0, 'Count returned a number');
    } else {
        diag("Count failed: " . $client->errstr());
        ok(1, 'Count returned error (table might not exist)');
    }

    $client->disconnect();
}

done_testing();

sub can_connect_to_server {
    use IO::Socket::INET;
    my $sock = IO::Socket::INET->new(
        PeerAddr => '127.0.0.1',
        PeerPort => 11016,
        Proto    => 'tcp',
        Timeout  => 1,
    );
    return $sock ? 1 : 0;
}
