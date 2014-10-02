#!/usr/bin/env perl
use v5.18;
use FindBin;
use lib "${FindBin::Bin}/../lib";

use Getopt::Std;
use Mailsheep::App;

my %opts;
getopts('na', \%opts);

my $app = Mailsheep::App->new(
    config_dir => "$ENV{HOME}/.config/mailsheep"
);
my $folder = shift || "INBOX";

$opts{'dry-run'} = $opts{n};
$opts{all} = $opts{a};

$app->categorize_new_messages($folder, \%opts);
