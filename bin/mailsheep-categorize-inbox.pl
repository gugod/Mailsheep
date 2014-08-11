#!/usr/bin/env perl
use v5.18;
use Data::Dumper;

use Mail::Box::Manager;
use Sereal::Decoder;
use Getopt::Std;
use File::Basename 'basename';

use FindBin;
use lib $FindBin::Bin . "/lib";

use Mailsheep::App;

my %opts;
getopts('d:', \%opts);

my $app = Mailsheep::App->new(
    maildir => "$ENV{HOME}/Maildir/",
    indexdir => $opts{d},
);

$app->categorize_new_messages();
