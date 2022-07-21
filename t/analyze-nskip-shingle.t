#!/usr/bin/env perl
use v5.36;
use Test2::V0;

use Importer 'Mailsheep::Analyzer' => 'nskip_shingle';

my @tokens = qw< this is a pencil . that is a book >;

my $ns2_tokens = nskip_shingle(1, \@tokens);

is(
    $ns2_tokens,
    array {
        item "this a";
        item "is pencil";
        item "a .";
        item "pencil that";
        item ". is";
        item "that a";
        item "is book";
        end();
    }
);

done_testing;
