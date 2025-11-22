package MygramDB::Client;

use 5.014;
use strict;
use warnings;
use IO::Socket::INET;
use Time::HiRes qw(time);
use Encode qw(encode_utf8 decode_utf8);
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

MygramDB::Client - Pure Perl client for MygramDB full-text search engine

=head1 SYNOPSIS

    use MygramDB::Client;

    # Create client
    my $client = MygramDB::Client->new(
        host    => 'localhost',
        port    => 11016,
        timeout => 5,
    );

    # Connect to server
    $client->connect() or die "Connection failed: " . $client->errstr;

    # Search
    my $result = $client->search(
        table => 'articles',
        query => 'hello world',
        limit => 100,
    );

    if ($result) {
        print "Found: $result->{total_count} results\n";
        for my $doc (@{$result->{results}}) {
            print "  - $doc->{primary_key}\n";
        }
    }

    # Count
    my $count = $client->count(
        table => 'articles',
        query => 'hello',
    );

    # Get document
    my $doc = $client->get(
        table       => 'articles',
        primary_key => '12345',
    );

    # Disconnect
    $client->disconnect();

=head1 DESCRIPTION

MygramDB::Client is a Pure Perl client library for MygramDB, a high-performance
in-memory full-text search engine with MySQL replication.

This module provides a complete implementation of the MygramDB protocol,
supporting all commands including SEARCH, COUNT, GET, INFO, and replication control.

=head1 METHODS

=head2 new(%options)

Create a new MygramDB client instance.

Options:

=over 4

=item * host - Server hostname (default: "127.0.0.1")

=item * port - Server port (default: 11016)

=item * timeout - Connection timeout in seconds (default: 5)

=item * recv_buffer_size - Receive buffer size in bytes (default: 65536)

=back

=cut

sub new {
    my ($class, %args) = @_;

    my $self = bless {
        host             => $args{host} || '127.0.0.1',
        port             => $args{port} || 11016,
        timeout          => $args{timeout} || 5,
        recv_buffer_size => $args{recv_buffer_size} || 65536,
        socket           => undef,
        connected        => 0,
        errstr           => '',
    }, $class;

    return $self;
}

=head2 connect()

Connect to MygramDB server.

Returns 1 on success, undef on error.

=cut

sub connect {
    my ($self) = @_;

    return 1 if $self->{connected};

    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Timeout  => $self->{timeout},
    );

    unless ($socket) {
        $self->{errstr} = "Failed to connect: $!";
        return undef;
    }

    $socket->autoflush(1);
    binmode($socket, ':raw');

    $self->{socket} = $socket;
    $self->{connected} = 1;
    $self->{errstr} = '';

    return 1;
}

=head2 disconnect()

Disconnect from server.

=cut

sub disconnect {
    my ($self) = @_;

    return unless $self->{connected};

    if ($self->{socket}) {
        close($self->{socket});
        $self->{socket} = undef;
    }

    $self->{connected} = 0;
}

=head2 is_connected()

Check if connected to server.

Returns 1 if connected, 0 otherwise.

=cut

sub is_connected {
    my ($self) = @_;
    return $self->{connected} ? 1 : 0;
}

=head2 errstr()

Get last error message.

=cut

sub errstr {
    my ($self) = @_;
    return $self->{errstr};
}

=head2 search(%options)

Search for documents.

Options:

=over 4

=item * table - Table name (required)

=item * query - Search query text (required)

=item * limit - Maximum number of results (default: 1000)

=item * offset - Result offset for pagination (default: 0)

=item * and_terms - ArrayRef of additional required terms

=item * not_terms - ArrayRef of excluded terms

=item * filters - HashRef of filter conditions

=item * sort_column - Column name for sorting

=item * sort_desc - Sort descending (1) or ascending (0), default: 1

=back

Returns HashRef with results on success, undef on error.

=cut

sub search {
    my ($self, %args) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $table = $args{table} or do {
        $self->{errstr} = "table parameter is required";
        return undef;
    };

    my $query = defined $args{query} ? $args{query} : do {
        $self->{errstr} = "query parameter is required";
        return undef;
    };

    my $limit       = $args{limit} // 1000;
    my $offset      = $args{offset} // 0;
    my $and_terms   = $args{and_terms} || [];
    my $not_terms   = $args{not_terms} || [];
    my $filters     = $args{filters} || {};
    my $sort_column = $args{sort_column} || '';
    my $sort_desc   = $args{sort_desc} // 1;

    # Build command
    my $cmd = "SEARCH $table $query";

    # Add AND terms
    if (@$and_terms) {
        $cmd .= " AND " . join(" AND ", @$and_terms);
    }

    # Add NOT terms
    if (@$not_terms) {
        $cmd .= " AND NOT " . join(" AND NOT ", @$not_terms);
    }

    # Add filters
    if (%$filters) {
        my @filter_parts;
        for my $key (sort keys %$filters) {
            push @filter_parts, "$key = $filters->{$key}";
        }
        $cmd .= " FILTER " . join(" AND ", @filter_parts);
    }

    # Add sort
    if ($sort_column) {
        $cmd .= " SORT $sort_column";
        $cmd .= $sort_desc ? " DESC" : " ASC";
    }

    # Add limit and offset
    if ($offset > 0) {
        $cmd .= " LIMIT $offset,$limit";
    } else {
        $cmd .= " LIMIT $limit";
    }

    my $response = $self->_send_command($cmd);
    return undef unless defined $response;

    return $self->_parse_search_response($response);
}

=head2 count(%options)

Count matching documents.

Options:

=over 4

=item * table - Table name (required)

=item * query - Search query text (required)

=item * and_terms - ArrayRef of additional required terms

=item * not_terms - ArrayRef of excluded terms

=item * filters - HashRef of filter conditions

=back

Returns count on success, undef on error.

=cut

sub count {
    my ($self, %args) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $table = $args{table} or do {
        $self->{errstr} = "table parameter is required";
        return undef;
    };

    my $query = defined $args{query} ? $args{query} : do {
        $self->{errstr} = "query parameter is required";
        return undef;
    };

    my $and_terms = $args{and_terms} || [];
    my $not_terms = $args{not_terms} || [];
    my $filters   = $args{filters} || {};

    # Build command
    my $cmd = "COUNT $table $query";

    # Add AND terms
    if (@$and_terms) {
        $cmd .= " AND " . join(" AND ", @$and_terms);
    }

    # Add NOT terms
    if (@$not_terms) {
        $cmd .= " AND NOT " . join(" AND NOT ", @$not_terms);
    }

    # Add filters
    if (%$filters) {
        my @filter_parts;
        for my $key (sort keys %$filters) {
            push @filter_parts, "$key = $filters->{$key}";
        }
        $cmd .= " FILTER " . join(" AND ", @filter_parts);
    }

    my $response = $self->_send_command($cmd);
    return undef unless defined $response;

    return $self->_parse_count_response($response);
}

=head2 get(%options)

Get document by primary key.

Options:

=over 4

=item * table - Table name (required)

=item * primary_key - Primary key value (required)

=back

Returns HashRef with document on success, undef on error.

=cut

sub get {
    my ($self, %args) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $table = $args{table} or do {
        $self->{errstr} = "table parameter is required";
        return undef;
    };

    my $primary_key = $args{primary_key};
    unless (defined $primary_key) {
        $self->{errstr} = "primary_key parameter is required";
        return undef;
    }

    my $cmd = "GET $table $primary_key";

    my $response = $self->_send_command($cmd);
    return undef unless defined $response;

    return $self->_parse_get_response($response);
}

=head2 info()

Get server information.

Returns HashRef with server info on success, undef on error.

=cut

sub info {
    my ($self) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $response = $self->_send_command("INFO");
    return undef unless defined $response;

    return $self->_parse_info_response($response);
}

=head2 enable_debug()

Enable debug mode for this connection.

Returns 1 on success, undef on error.

=cut

sub enable_debug {
    my ($self) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $response = $self->_send_command("DEBUG ON");
    return undef unless defined $response;

    return $response =~ /^OK DEBUG_ON/ ? 1 : undef;
}

=head2 disable_debug()

Disable debug mode for this connection.

Returns 1 on success, undef on error.

=cut

sub disable_debug {
    my ($self) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $response = $self->_send_command("DEBUG OFF");
    return undef unless defined $response;

    return $response =~ /^OK DEBUG_OFF/ ? 1 : undef;
}

=head2 sync(%options)

Manually trigger snapshot synchronization.

Options:

=over 4

=item * table - Table name (required)

=back

Returns 1 on success, undef on error.

=cut

sub sync {
    my ($self, %args) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $table = $args{table} or do {
        $self->{errstr} = "table parameter is required";
        return undef;
    };

    my $response = $self->_send_command("SYNC $table");
    return undef unless defined $response;

    return $response =~ /^OK SYNC STARTED/ ? 1 : undef;
}

=head2 replication_status()

Get replication status.

Returns HashRef with status on success, undef on error.

=cut

sub replication_status {
    my ($self) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $response = $self->_send_command("REPLICATION STATUS");
    return undef unless defined $response;

    return $self->_parse_replication_status($response);
}

=head2 send_command($command)

Send raw command to server.

Returns response string on success, undef on error.

This is a low-level interface. Most users should use the higher-level methods.

=cut

sub send_command {
    my ($self, $command) = @_;
    return $self->_send_command($command);
}

# Private methods

sub _send_command {
    my ($self, $command) = @_;

    unless ($self->{connected}) {
        $self->{errstr} = "Not connected";
        return undef;
    }

    my $socket = $self->{socket};

    # Send command (UTF-8 encoded)
    my $cmd_bytes = encode_utf8($command) . "\r\n";

    my $sent = eval { print {$socket} $cmd_bytes };
    unless ($sent) {
        $self->{errstr} = "Failed to send command: $!";
        $self->{connected} = 0;
        return undef;
    }

    # Receive response
    my $response = '';
    my $buffer;

    while (1) {
        my $bytes_read = sysread($socket, $buffer, $self->{recv_buffer_size});

        unless (defined $bytes_read) {
            $self->{errstr} = "Failed to read response: $!";
            $self->{connected} = 0;
            return undef;
        }

        if ($bytes_read == 0) {
            $self->{errstr} = "Connection closed by server";
            $self->{connected} = 0;
            return undef;
        }

        $response .= $buffer;

        # Check for end of response (newline)
        if ($response =~ /\n/) {
            last;
        }
    }

    # Decode UTF-8
    $response = decode_utf8($response);

    # Trim whitespace
    $response =~ s/^\s+|\s+$//g;

    # Check for error
    if ($response =~ /^ERROR (.+)/) {
        $self->{errstr} = $1;
        return undef;
    }

    if ($response =~ /^\(error\) (.+)/) {
        $self->{errstr} = $1;
        return undef;
    }

    return $response;
}

sub _parse_search_response {
    my ($self, $response) = @_;

    # OK RESULTS <total_count> <id1> <id2> ...
    if ($response =~ /^OK RESULTS (\d+)\s*(.*)/) {
        my $total_count = $1;
        my $ids_str = $2 || '';

        my @ids = split /\s+/, $ids_str;

        my @results;
        for my $id (@ids) {
            next unless length $id;
            push @results, { primary_key => $id };
        }

        return {
            total_count => $total_count,
            results     => \@results,
        };
    }

    $self->{errstr} = "Invalid search response: $response";
    return undef;
}

sub _parse_count_response {
    my ($self, $response) = @_;

    # OK COUNT <number>
    if ($response =~ /^OK COUNT (\d+)/) {
        return $1;
    }

    $self->{errstr} = "Invalid count response: $response";
    return undef;
}

sub _parse_get_response {
    my ($self, $response) = @_;

    # DOC <primary_key> <field1=value1> <field2=value2> ...
    if ($response =~ /^DOC (\S+)\s*(.*)/) {
        my $primary_key = $1;
        my $fields_str = $2 || '';

        my %fields;
        for my $field (split /\s+/, $fields_str) {
            if ($field =~ /^([^=]+)=(.*)$/) {
                $fields{$1} = $2;
            }
        }

        return {
            primary_key => $primary_key,
            fields      => \%fields,
        };
    }

    $self->{errstr} = "Invalid get response: $response";
    return undef;
}

sub _parse_info_response {
    my ($self, $response) = @_;

    # OK INFO
    # <multi-line response>
    unless ($response =~ /^OK INFO/) {
        $self->{errstr} = "Invalid info response: $response";
        return undef;
    }

    # For now, return raw response
    # TODO: Parse into structured data
    return { raw => $response };
}

sub _parse_replication_status {
    my ($self, $response) = @_;

    # OK REPLICATION status=<running|stopped> gtid=<gtid>
    if ($response =~ /^OK REPLICATION status=(\S+)\s+gtid=(.+)/) {
        return {
            status => $1,
            gtid   => $2,
        };
    }

    $self->{errstr} = "Invalid replication status response: $response";
    return undef;
}

sub DESTROY {
    my ($self) = @_;
    $self->disconnect() if $self->{connected};
}

=head2 parse_search_expression($expression)

Parse web-style search expression into structured components.

Supported syntax:

=over 4

=item * C<+term> - Required term (AND)

=item * C<-term> - Excluded term (NOT)

=item * C<term> - Optional term

=item * C<"phrase"> - Quoted phrase

=item * C<OR> - Logical OR operator

=item * C<()> - Grouping

=back

Examples:

    my $parsed = MygramDB::Client->parse_search_expression("+golang -old tutorial");
    # {
    #   main_term => "golang",
    #   and_terms => [],
    #   not_terms => ["old"],
    #   optional_terms => ["tutorial"]
    # }

Returns hashref with:

=over 4

=item * main_term - Main search term

=item * and_terms - ArrayRef of required terms (AND)

=item * not_terms - ArrayRef of excluded terms (NOT)

=item * optional_terms - ArrayRef of optional terms (OR)

=back

=cut

sub parse_search_expression {
    my ($class_or_self, $expression) = @_;

    return undef unless defined $expression;

    my @required;
    my @excluded;
    my @optional;
    my $in_quote = 0;
    my $current_term = '';
    my $prefix = '';

    # Simple tokenizer
    my @chars = split //, $expression;

    for (my $i = 0; $i < @chars; $i++) {
        my $char = $chars[$i];

        if ($char eq '"') {
            $in_quote = !$in_quote;
            $current_term .= $char;
        }
        elsif ($in_quote) {
            $current_term .= $char;
        }
        elsif ($char =~ /\s/ || $i == $#chars) {
            # Add last character if end of string
            $current_term .= $char if $i == $#chars && $char !~ /\s/;

            if (length $current_term) {
                # Remove quotes
                $current_term =~ s/^"(.*)"$/$1/;

                # Determine category
                if ($current_term =~ /^([+\-])(.+)/) {
                    $prefix = $1;
                    $current_term = $2;
                }

                # Skip OR operator (simplified - just treat as optional)
                next if uc($current_term) eq 'OR';

                if ($prefix eq '+') {
                    push @required, $current_term;
                }
                elsif ($prefix eq '-') {
                    push @excluded, $current_term;
                }
                else {
                    push @optional, $current_term;
                }

                $current_term = '';
                $prefix = '';
            }
        }
        else {
            $current_term .= $char;
        }
    }

    # Get main term (first required or first optional)
    my $main_term = @required ? $required[0] : (@optional ? $optional[0] : '');

    # Remove main term from its list
    if (@required && $main_term eq $required[0]) {
        shift @required;
    }
    elsif (@optional && $main_term eq $optional[0]) {
        shift @optional;
    }

    return {
        main_term      => $main_term,
        and_terms      => \@required,
        not_terms      => \@excluded,
        optional_terms => \@optional,
    };
}

1;

=head1 SEE ALSO

L<MygramDB::Client::XS> - XS-based high-performance client

L<https://github.com/libraz/mygram-db> - MygramDB project

=head1 AUTHOR

libraz E<lt>libraz@libraz.netE<gt>

=head1 LICENSE

MIT License

=cut
