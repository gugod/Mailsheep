#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

use Test::More;

use Mailsheep::Analyzer;

my @tokens = qw< this is a pencil . that is a book >;

my $ns2_tokens = Mailsheep::Analyzer::nskip_shingle(1, \@tokens);

is_deeply(
    $ns2_tokens,
    [
        "this a",
        "is pencil",
        "a .",
        "pencil that",
        ". is",
        "that a",
        "is book",
    ]
);


done_testing;
