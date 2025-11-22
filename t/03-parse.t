#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 35;

use_ok('MygramDB::Client');

# Test 1: Simple term
{
    my $parsed = MygramDB::Client->parse_search_expression('golang');
    is($parsed->{main_term}, 'golang', 'Simple term - main_term');
    is(scalar @{$parsed->{and_terms}}, 0, 'Simple term - no and_terms');
    is(scalar @{$parsed->{not_terms}}, 0, 'Simple term - no not_terms');
}

# Test 2: Required and excluded terms
{
    my $parsed = MygramDB::Client->parse_search_expression('+golang -old tutorial');
    is($parsed->{main_term}, 'golang', 'Complex - main_term');
    is(scalar @{$parsed->{and_terms}}, 0, 'Complex - and_terms empty (main is required)');
    is(scalar @{$parsed->{not_terms}}, 1, 'Complex - one not_term');
    is($parsed->{not_terms}[0], 'old', 'Complex - not_term value');
    is(scalar @{$parsed->{optional_terms}}, 1, 'Complex - one optional_term');
    is($parsed->{optional_terms}[0], 'tutorial', 'Complex - optional_term value');
}

# Test 3: Multiple required terms
{
    my $parsed = MygramDB::Client->parse_search_expression('+golang +tutorial -deprecated');
    is($parsed->{main_term}, 'golang', 'Multiple required - main_term is first');
    is(scalar @{$parsed->{and_terms}}, 1, 'Multiple required - second term in and_terms');
    is($parsed->{and_terms}[0], 'tutorial', 'Multiple required - and_term value');
}

# Test 4: Quoted phrases
{
    my $parsed = MygramDB::Client->parse_search_expression('"machine learning" tutorial');
    is($parsed->{main_term}, 'machine learning', 'Quoted phrase - main_term');
    is(scalar @{$parsed->{optional_terms}}, 1, 'Quoted phrase - has optional term');
    is($parsed->{optional_terms}[0], 'tutorial', 'Quoted phrase - optional term value');
}

# Test 5: Multiple exclusions
{
    my $parsed = MygramDB::Client->parse_search_expression('golang -old -deprecated -legacy');
    is($parsed->{main_term}, 'golang', 'Multiple exclusions - main_term');
    is(scalar @{$parsed->{not_terms}}, 3, 'Multiple exclusions - three not_terms');
    is($parsed->{not_terms}[0], 'old', 'Multiple exclusions - first not_term');
    is($parsed->{not_terms}[1], 'deprecated', 'Multiple exclusions - second not_term');
    is($parsed->{not_terms}[2], 'legacy', 'Multiple exclusions - third not_term');
}

# Test 6: Only optional terms
{
    my $parsed = MygramDB::Client->parse_search_expression('python ruby javascript');
    is($parsed->{main_term}, 'python', 'Optional only - main_term is first');
    is(scalar @{$parsed->{optional_terms}}, 2, 'Optional only - two optional_terms');
    is($parsed->{optional_terms}[0], 'ruby', 'Optional only - first optional');
    is($parsed->{optional_terms}[1], 'javascript', 'Optional only - second optional');
}

# Test 7: Empty string
{
    my $parsed = MygramDB::Client->parse_search_expression('');
    is($parsed->{main_term}, '', 'Empty string - main_term is empty');
    is(scalar @{$parsed->{and_terms}}, 0, 'Empty string - no and_terms');
    is(scalar @{$parsed->{not_terms}}, 0, 'Empty string - no not_terms');
}

# Test 8: Only exclusions (edge case)
{
    my $parsed = MygramDB::Client->parse_search_expression('-old -deprecated');
    is($parsed->{main_term}, '', 'Only exclusions - main_term is empty');
    is(scalar @{$parsed->{not_terms}}, 2, 'Only exclusions - two not_terms');
}

# Test 9: Mixed with OR (simplified handling)
{
    my $parsed = MygramDB::Client->parse_search_expression('+golang tutorial OR guide');
    is($parsed->{main_term}, 'golang', 'With OR - main_term');
    is(scalar @{$parsed->{optional_terms}}, 2, 'With OR - OR is treated as optional');
}

# Test 10: Unicode/CJK support
{
    my $parsed = MygramDB::Client->parse_search_expression('+機械学習 -古い チュートリアル');
    is($parsed->{main_term}, '機械学習', 'Unicode - main_term (CJK)');
    is($parsed->{not_terms}[0], '古い', 'Unicode - not_term (CJK)');
    is($parsed->{optional_terms}[0], 'チュートリアル', 'Unicode - optional_term (CJK)');
}
