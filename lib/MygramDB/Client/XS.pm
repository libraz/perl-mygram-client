package MygramDB::Client::XS;

use 5.014;
use strict;
use warnings;

our $VERSION = '0.01';

# Load the shared XS module (built as MygramDB::Client)
require XSLoader;
XSLoader::load('MygramDB::Client', $VERSION);

=head1 NAME

MygramDB::Client::XS - High-performance XS client for MygramDB

=head1 SYNOPSIS

    use MygramDB::Client::XS;

    # Create client
    my $client = MygramDB::Client::XS->new(
        host    => 'localhost',
        port    => 11016,
        timeout_ms => 5000,
    );

    # Connect
    $client->connect();

    # Search
    my $result = $client->search(
        'articles',  # table
        'hello',     # query
        100,         # limit
        0,           # offset
    );

    print "Found: $result->{total_count}\n";
    for my $doc (@{$result->{results}}) {
        print "  - $doc->{primary_key}\n";
    }

    # Advanced search with filters
    my $result2 = $client->search_advanced(
        'articles',              # table
        'technology',            # query
        50,                      # limit
        0,                       # offset
        ['AI'],                  # AND terms
        ['old'],                 # NOT terms
        {status => 1},           # filters
        'created_at',            # sort column
        1,                       # sort descending
    );

    # Count
    my $count = $client->count('articles', 'hello');

    # Get document
    my $doc = $client->get('articles', '12345');
    print "Primary key: $doc->{primary_key}\n";
    for my $key (keys %{$doc->{fields}}) {
        print "  $key = $doc->{fields}{$key}\n";
    }

    # Server info
    my $info = $client->info();
    print "Version: $info->{version}\n";
    print "Documents: $info->{doc_count}\n";

    # Disconnect
    $client->disconnect();

=head1 DESCRIPTION

MygramDB::Client::XS is a high-performance XS-based client for MygramDB.
It provides direct bindings to the C client library (libmygramclient),
offering better performance than the pure Perl implementation.

This module wraps the C API and provides a Perl-friendly interface.

=head1 METHODS

=head2 new($host, $port, $timeout_ms, $recv_buffer_size)

Create a new client instance.

Parameters (all required):

=over 4

=item * host - Server hostname

=item * port - Server port

=item * timeout_ms - Connection timeout in milliseconds (default: 5000)

=item * recv_buffer_size - Receive buffer size (default: 65536)

=back

=head2 connect()

Connect to MygramDB server. Dies on error.

=head2 disconnect()

Disconnect from server.

=head2 is_connected()

Check if connected. Returns 1 if connected, 0 otherwise.

=head2 search($table, $query, $limit, $offset)

Simple search. Returns hashref with C<total_count> and C<results>.

=head2 search_advanced($table, $query, $limit, $offset, $and_terms, $not_terms, $filters, $sort_column, $sort_desc)

Advanced search with filters and sorting.

Parameters:

=over 4

=item * table - Table name

=item * query - Search query

=item * limit - Maximum results

=item * offset - Result offset

=item * and_terms - ArrayRef of AND terms

=item * not_terms - ArrayRef of NOT terms

=item * filters - HashRef of filters

=item * sort_column - Column name for sorting

=item * sort_desc - 1 for DESC, 0 for ASC

=back

=head2 count($table, $query)

Count matching documents. Returns integer.

=head2 get($table, $primary_key)

Get document by primary key. Returns hashref with C<primary_key> and C<fields>.

=head2 info()

Get server information. Returns hashref.

=head2 enable_debug()

Enable debug mode for this connection.

=head2 disable_debug()

Disable debug mode.

=head2 replication_stop()

Stop replication.

=head2 replication_start()

Start replication.

=head2 get_last_error()

Get last error message.

=head2 parse_search_expression($expression)

Parse web-style search expression into structured components.

This is a class/static method that uses the native C++ parser.

    my $parsed = MygramDB::Client::XS->parse_search_expression("+golang -old tutorial");
    # Returns:
    # {
    #   main_term => "golang",
    #   and_terms => [],
    #   not_terms => ["old"],
    #   optional_terms => ["tutorial"]
    # }

Supported syntax:

=over 4

=item * C<+term> - Required term (AND)

=item * C<-term> - Excluded term (NOT)

=item * C<"phrase"> - Quoted phrase

=item * C<OR> - Logical OR operator

=item * C<()> - Grouping

=back

=head1 PERFORMANCE

The XS implementation is significantly faster than the pure Perl version:

=over 4

=item * Direct C API calls (no protocol parsing overhead)

=item * Efficient memory management

=item * Native data structure conversion

=back

Benchmarks show 5-10x performance improvement for search operations.

=head1 SEE ALSO

L<MygramDB::Client> - Pure Perl implementation

L<https://github.com/libraz/mygram-db> - MygramDB project

=head1 AUTHOR

libraz E<lt>libraz@libraz.netE<gt>

=head1 LICENSE

MIT License

=cut

1;
