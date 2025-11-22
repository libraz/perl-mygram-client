# MygramDB::Client - Perl Client for MygramDB

Perl client library for [MygramDB](https://github.com/libraz/mygram-db), a high-performance in-memory full-text search engine with MySQL replication.

## Features

- **Dual Implementation**: Pure Perl and XS (C bindings) versions
- **Full Protocol Support**: All MygramDB commands (SEARCH, COUNT, GET, INFO, etc.)
- **Unicode Support**: Full UTF-8 support including CJK and emoji
- **Easy Installation**: Standard CPAN-style installation with Makefile.PL
- **High Performance**: XS version provides 5-10x performance improvement
- **Self-Contained**: Can build from embedded source without external dependencies

## Quick Start

```bash
# 1. Build and install (embedded source already included)
perl Makefile.PL
make
make test
sudo make install

# 2. Use in your code
perl -e 'use MygramDB::Client; print "Ready!\n"'
```

See [examples/simple.pl](examples/simple.pl) for a complete working example.

## Installation

### Prerequisites

**Minimum requirements:**
- Perl 5.14 or later
- make

**For XS module (optional, for better performance):**
- C++ compiler (g++, clang++)
- MygramDB source (for embedded build) OR libmygramclient (for system build)

### Build Modes

This distribution includes embedded MygramDB client source, allowing it to build standalone without external dependencies. The build system automatically detects and uses the best available option:

1. **Embedded Source** (Default - Already Included)
   ```bash
   perl Makefile.PL  # Detects: "Using embedded libmygramclient source"
   make
   ```
   - ✅ No external dependencies required
   - ✅ Fully self-contained distribution
   - ✅ Works out of the box

2. **System Library** (Optional - If MygramDB installed)
   ```bash
   # If you have MygramDB installed system-wide
   perl Makefile.PL  # Detects: "Found libmygramclient at: /usr/local"
   make
   ```
   - Uses system-installed libmygramclient
   - May be newer version

3. **Pure Perl Only** (No Compiler)
   ```bash
   # If no C++ compiler available
   perl Makefile.PL  # "XS module will not be built"
   make
   ```
   - ✅ No compiler needed
   - ✅ Portable to any platform
   - Slower performance (but still functional)

### Standard Installation

```bash
perl Makefile.PL
make
make test
sudo make install
```

### Verify Installation

```bash
# Check Pure Perl version
perl -MMygramDB::Client -e 'print "Pure Perl: OK\n"'

# Check XS version (if built)
perl -MMygramDB::Client::XS -e 'print "XS: OK\n"'
```

## Usage

### Pure Perl Version

```perl
use MygramDB::Client;

my $client = MygramDB::Client->new(
    host    => 'localhost',
    port    => 11016,
    timeout => 5,
);

$client->connect() or die $client->errstr;

# Simple search
my $result = $client->search(
    table => 'articles',
    query => 'hello world',
    limit => 100,
);

print "Found: $result->{total_count} results\n";
for my $doc (@{$result->{results}}) {
    print "  - $doc->{primary_key}\n";
}

# Advanced search with AND/NOT terms and filters
my $result2 = $client->search(
    table      => 'articles',
    query      => 'technology',
    and_terms  => ['AI', 'machine learning'],  # Must contain these
    not_terms  => ['old', 'deprecated'],        # Must NOT contain these
    filters    => { status => 1, category => 'tech' },  # Field filters
    sort_column => 'created_at',
    sort_desc  => 1,  # Descending order
    limit      => 50,
);

# Count matching documents
my $count = $client->count(
    table => 'articles',
    query => 'hello',
);
print "Total matches: $count\n";

# Get document by primary key
my $doc = $client->get(
    table       => 'articles',
    primary_key => '12345',
);
print "Title: $doc->{fields}{title}\n";

$client->disconnect();
```

### Parsing User Search Queries

Both Pure Perl and XS versions support parsing web-style search expressions:

```perl
use MygramDB::Client;

# Parse user input like Google search
my $parsed = MygramDB::Client->parse_search_expression('+golang -old "web framework"');

# Returns:
# {
#   main_term      => 'golang',
#   and_terms      => [],
#   not_terms      => ['old'],
#   optional_terms => ['web framework']
# }

# Use parsed components in search
my $client = MygramDB::Client->new(host => 'localhost', port => 11016);
$client->connect();

my $result = $client->search(
    table      => 'articles',
    query      => $parsed->{main_term},
    and_terms  => $parsed->{and_terms},
    not_terms  => $parsed->{not_terms},
    limit      => 100,
);
```

The parser supports:
- `+term` - Required terms (AND)
- `-term` - Excluded terms (NOT)
- `"phrase"` - Quoted phrases
- `OR` - Logical OR operator
- `()` - Grouping (XS version uses native C++ parser)

### XS Version (High Performance)

```perl
use MygramDB::Client::XS;

my $client = MygramDB::Client::XS->new(
    'localhost',  # host
    11016,        # port
    5000,         # timeout_ms
    65536,        # recv_buffer_size
);

$client->connect();

# Simple search
my $result = $client->search(
    'articles',  # table
    'hello',     # query
    100,         # limit
    0,           # offset
);

# Advanced search with filters
my $result2 = $client->search_advanced(
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

$client->disconnect();
```

## Examples

See the `examples/` directory for more examples:

- `simple.pl` - Basic Pure Perl usage
- `xs_example.pl` - XS version usage
- `benchmark.pl` - Performance comparison between Pure Perl and XS

## Documentation

Full documentation is available via perldoc:

```bash
perldoc MygramDB::Client
perldoc MygramDB::Client::XS
```

## API Reference

### Constructor Options (Pure Perl)

- `host` - Server hostname (default: "127.0.0.1")
- `port` - Server port (default: 11016)
- `timeout` - Connection timeout in seconds (default: 5)
- `recv_buffer_size` - Receive buffer size (default: 65536)

### XS Constructor

```perl
MygramDB::Client::XS->new($host, $port, $timeout_ms, $recv_buffer_size)
```

### Methods

#### Connection

- `connect()` - Connect to server
- `disconnect()` - Disconnect from server
- `is_connected()` - Check connection status

#### Search Operations

- `search(%options)` - Search for documents
  - **table** (required) - Table name
  - **query** (required) - Search query text
  - **limit** (optional, default: 1000) - Maximum results
  - **offset** (optional, default: 0) - Pagination offset
  - **and_terms** (optional) - ArrayRef of required terms (all must match)
  - **not_terms** (optional) - ArrayRef of excluded terms (none can match)
  - **filters** (optional) - HashRef of field filters (e.g., `{status => 1}`)
  - **sort_column** (optional) - Column name for sorting
  - **sort_desc** (optional, default: 1) - Sort descending (1) or ascending (0)

- `count(%options)` - Count matching documents
  - **table** (required) - Table name
  - **query** (required) - Search query text

- `get(%options)` - Get document by primary key
  - **table** (required) - Table name
  - **primary_key** (required) - Document primary key

#### Server Operations

- `info()` - Get server information
- `sync(%options)` - Trigger snapshot synchronization
- `replication_status()` - Get replication status

#### Debug

- `enable_debug()` - Enable debug mode
- `disable_debug()` - Disable debug mode

#### Utility

- `parse_search_expression($expression)` - Parse web-style search expression (class method)
  - **expression** (required) - Web-style search string (e.g., `"+golang -old tutorial"`)
  - Returns hashref with:
    - **main_term** - Main search term
    - **and_terms** - ArrayRef of required terms
    - **not_terms** - ArrayRef of excluded terms
    - **optional_terms** - ArrayRef of optional terms

#### Low-level

- `send_command($command)` - Send raw command (Pure Perl only)

## Performance

Benchmark results (100 searches):

```
Pure Perl: 100 searches in 0.523s (avg: 0.00523s)
XS:        100 searches in 0.091s (avg: 0.00091s)

XS is 5.75x faster than Pure Perl
```

## Testing

```bash
make test
```

**Note:** Basic tests run without a server. Advanced tests require MygramDB running on `localhost:11016`.

To start MygramDB for testing:

```bash
docker run -d --name mygramdb \
  -p 11016:11016 \
  -e MYSQL_HOST=your-mysql-host \
  -e MYSQL_USER=repl_user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_DATABASE=mydb \
  -e TABLE_NAME=articles \
  -e TABLE_PRIMARY_KEY=id \
  -e TABLE_TEXT_COLUMN=content \
  ghcr.io/libraz/mygram-db:latest

# Initialize data
docker exec mygramdb mygram-cli -p 11016 SYNC articles
```

## Troubleshooting

### XS Module Won't Build

**Check if libmygramclient is available:**
```bash
ls /usr/local/include/mygramdb/
ls /usr/local/lib/libmygramclient.*
```

**Try embedded source build:**
```bash
./embed-source.sh ../mygram-db
perl Makefile.PL
make
```

### macOS Compilation Issues

If you see "cstring file not found" or similar C++ header errors:

```bash
# The build system should auto-detect SDK paths
# If it fails, check your Xcode installation:
xcode-select --install
xcrun --show-sdk-path
```

### Runtime Library Not Found (macOS)

```bash
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

For bundled libraries, the build system automatically sets rpath.

### Tests Fail

Make sure MygramDB server is running and accessible:
```bash
telnet localhost 11016
```

## Distribution

Create a distributable tarball:

```bash
make dist
```

This creates `MygramDB-Client-X.XX.tar.gz` which can be distributed via CPAN or directly.

For CPAN upload:
```bash
cpan-upload MygramDB-Client-0.01.tar.gz
```

## License

MIT License

## Author

libraz <libraz@libraz.net>

## See Also

- [MygramDB](https://github.com/libraz/mygram-db) - The MygramDB project
- [Protocol Documentation](https://github.com/libraz/mygram-db/blob/main/docs/en/protocol.md)
- [Client Library Documentation](https://github.com/libraz/mygram-db/blob/main/docs/en/libmygramclient.md)
