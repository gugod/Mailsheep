#!/usr/bin/env perl
use v5.14; use strict; use warnings;
use Getopt::Std;
use YAML;
use Encode qw(encode_utf8);
use Sereal::Encoder;

use FindBin;
use lib $FindBin::Bin . "/../lib";

use Mail::Box::Manager;

use Mailsheep::App;
use Mailsheep::Categorizer;

my $app = Mailsheep::App->new(config_dir => "$ENV{HOME}/.config/mailsheep");
$app->train_with_old_messages;
