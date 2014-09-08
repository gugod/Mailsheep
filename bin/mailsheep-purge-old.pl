#!/usr/bin/env perl
use v5.14; use strict; use warnings;

use FindBin;
use lib $FindBin::Bin . "/../lib";

use Mailsheep::App;

my $app = Mailsheep::App->new(config_dir => "$ENV{HOME}/.config/mailsheep");
$app->purge_old_messages;

