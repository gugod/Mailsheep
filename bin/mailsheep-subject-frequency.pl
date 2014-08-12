#!/usr/bin/env perl
use v5.14; use strict; use warnings;
use FindBin;
use lib $FindBin::Bin . "/../lib";

use Getopt::Std;
use YAML;
use Mailsheep::App;

my %opts;
getopts('d:', \%opts);
binmode STDOUT, ":utf8";

my $box = shift or die;
my $app = Mailsheep::App->new(maildir => "$ENV{HOME}/Maildir/", indexdir => $opts{d});

my $ft = $app->subject_frequency($box);

my @subject = sort { $ft->{$b} <=> $ft->{$a} } keys %$ft;
for (@subject) {
    printf("%5d\t%s\n", $ft->{$_}, $_);
}
