#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MygramDB::Client;

# Test client creation
my $client = MygramDB::Client->new(
    host    => '127.0.0.1',
    port    => 11016,
    timeout => 5,
);

isa_ok($client, 'MygramDB::Client');

# Test initial state
is($client->is_connected(), 0, 'Initially not connected');

# Connection test (only if server is available)
SKIP: {
    skip "MygramDB server not available", 5 unless can_connect_to_server();

    # Connect
    ok($client->connect(), 'Connect to server');
    is($client->is_connected(), 1, 'Connected state');

    # Info
    my $info = $client->info();
    ok($info, 'Got server info');
    ok(exists $info->{raw}, 'Info has raw response');

    # Disconnect
    $client->disconnect();
    is($client->is_connected(), 0, 'Disconnected state');
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
