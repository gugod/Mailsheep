#!/usr/bin/env perl
use v5.36;
use Test2::V0;

use Importer 'Mailsheep::Analyzer' => 'normalize_whitespace';

my $txt0 = " penny  kitty   mouse    brown ";
my $txt1 = $txt0;

my $txt2 = normalize_whitespace($txt1);

is $txt1, $txt0, "input argument is not changed";
like $txt2, qr/ /, "whitespaces are there.";
unlike $txt2, qr/  /, "whitespaces are alone.";
like $txt2, qr/^\S.+\S$/, "trimmed";

done_testing;
