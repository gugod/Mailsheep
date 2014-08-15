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

my $app = Mailsheep::App->new(
    config_dir => "$ENV{HOME}/.config/mailsheep"
);

$app->categorize_new_messages();
