use 5.014;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Copy;
use File::Path qw(make_path);

# Check for libmygramclient installation
my $has_libmygramclient = 0;
my $mygramclient_inc = '';
my $mygramclient_lib = '';
my $use_bundled = 0;
my $use_embedded = 0;

# First, check for bundled library (in vendor/)
if (-d 'vendor/lib' && -d 'vendor/include') {
    if (-f 'vendor/include/mygramdb/mygramclient_c.h') {
        $has_libmygramclient = 1;
        $mygramclient_inc = 'vendor/include';
        $mygramclient_lib = 'vendor/lib';
        $use_bundled = 1;
        print "Using bundled libmygramclient from vendor/\n";
    }
}

# Check for embedded source (in src/)
unless ($has_libmygramclient) {
    if (-d 'src' && -f 'src/mygramclient_c.cpp') {
        $has_libmygramclient = 1;
        $mygramclient_inc = 'src';
        $use_embedded = 1;
        print "Using embedded libmygramclient source from src/\n";
    }
}

# If not bundled/embedded, try to find system-installed libmygramclient
unless ($has_libmygramclient) {
    foreach my $prefix ('/usr/local', '/usr', $ENV{HOME}) {
        if (-f "$prefix/include/mygramdb/mygramclient_c.h") {
            $has_libmygramclient = 1;
            $mygramclient_inc = "$prefix/include";
            $mygramclient_lib = "$prefix/lib";
            last;
        }
    }
}

# XS configuration
my %xs_params;
if ($has_libmygramclient) {
    print "Found libmygramclient at: $mygramclient_inc\n";

    if ($use_embedded) {
        # Build from embedded source
        print "Building XS module with embedded source\n";

        %xs_params = (
            OBJECT => '$(O_FILES) src/mygramclient_c.o src/mygramclient.o src/search_expression.o src/string_utils.o src/network_utils.o',
            XS     => { 'Client.xs' => 'Client.c' },
            INC    => "-Isrc -std=c++17",
            XSOPT  => '-C++',
            CC     => 'c++',
            LD     => 'c++',
            DEFINE => '-DUSE_EMBEDDED_SOURCE',
        );
    } elsif ($use_bundled) {
        # Use bundled pre-built library
        my $lib_flags = ["-L$mygramclient_lib -lmygramclient"];

        # Add rpath for runtime (macOS/Linux)
        if ($^O eq 'darwin') {
            $lib_flags->[0] .= " -Wl,-rpath,\@loader_path/../vendor/lib";
        } else {
            $lib_flags->[0] .= " -Wl,-rpath,\\\$\$ORIGIN/../vendor/lib";
        }

        %xs_params = (
            OBJECT => '$(O_FILES)',
            XS     => { 'Client.xs' => 'Client.c' },
            INC    => "-I$mygramclient_inc",
            LIBS   => $lib_flags,
        );
    } else {
        # Use system library
        %xs_params = (
            OBJECT => '$(O_FILES)',
            XS     => { 'Client.xs' => 'Client.c' },
            INC    => "-I$mygramclient_inc",
            LIBS   => ["-L$mygramclient_lib -lmygramclient"],
        );
    }
} else {
    print "libmygramclient not found. XS module will not be built.\n";
    print "Pure Perl implementation will still be available.\n";
    print "\n";
    print "To build XS module:\n";
    print "  1. Install libmygramclient: cd /path/to/mygram-db && make && sudo make install\n";
    print "  2. Bundle the library: ./bundle-library.sh ../mygram-db\n";
    print "  3. Or embed source: ./embed-source.sh ../mygram-db\n";
    %xs_params = (
        XS => {},
        C  => [],
    );
}

WriteMakefile(
    NAME             => 'MygramDB::Client',
    AUTHOR           => 'libraz <libraz@libraz.net>',
    VERSION_FROM     => 'lib/MygramDB/Client.pm',
    ABSTRACT_FROM    => 'lib/MygramDB/Client.pm',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.014',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0.98',
    },
    PREREQ_PM => {
        'IO::Socket::INET' => '0',
        'Time::HiRes'      => '0',
        'Encode'           => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/libraz/perl-mygram-client.git',
                web  => 'https://github.com/libraz/perl-mygram-client',
            },
            bugtracker => {
                web => 'https://github.com/libraz/perl-mygram-client/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'MygramDB-Client-* Client.c Client.o src/*.o' },
    %xs_params,
);

# Custom compilation rules for embedded C++ source
sub MY::postamble {
    return '' unless $use_embedded;

    my $cxx = 'c++';
    my $cxxflags = '-std=c++17 -O2 -Wall -fPIC';
    my $includes = '-Isrc';

    if ($^O eq 'darwin') {
        # Get macOS SDK path
        my $sdk_path = `xcrun --show-sdk-path 2>/dev/null`;
        chomp($sdk_path);

        if ($sdk_path && -d $sdk_path) {
            # Use libc++ explicitly
            $cxxflags .= ' -stdlib=libc++';
            $cxxflags .= " -isysroot $sdk_path";

            # Explicitly add C++ standard library headers (from CMakeLists.txt)
            $includes .= " -isystem $sdk_path/usr/include/c++/v1";
            $includes .= " -isystem $sdk_path/usr/include";
        }

        # Add Homebrew paths if available
        if (-d '/opt/homebrew/include') {
            $includes .= ' -isystem /opt/homebrew/include';
        }
        if (-d '/usr/local/include') {
            $includes .= ' -isystem /usr/local/include';
        }

        # macOS-specific options
        $cxxflags .= ' -Wno-unused-command-line-argument -Qunused-arguments';
    }

    my $compile_cmd = "$cxx $cxxflags $includes";

    return qq{
src/mygramclient_c.o: src/mygramclient_c.cpp
\t$compile_cmd -c src/mygramclient_c.cpp -o src/mygramclient_c.o

src/mygramclient.o: src/mygramclient.cpp
\t$compile_cmd -c src/mygramclient.cpp -o src/mygramclient.o

src/search_expression.o: src/search_expression.cpp
\t$compile_cmd -c src/search_expression.cpp -o src/search_expression.o

src/string_utils.o: src/string_utils.cpp
\t$compile_cmd -c src/string_utils.cpp -o src/string_utils.o

src/network_utils.o: src/network_utils.cpp
\t$compile_cmd -c src/network_utils.cpp -o src/network_utils.o
};
}
