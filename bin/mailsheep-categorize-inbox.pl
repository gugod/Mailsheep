#!/usr/bin/env perl
use v5.18;
use FindBin;
use lib $FindBin::Bin . "/lib";

use Mailsheep::App;

my $app = Mailsheep::App->new(
    config_dir => "$ENV{HOME}/.config/mailsheep"
);

$app->categorize_new_messages();
