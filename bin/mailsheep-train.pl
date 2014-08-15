#!/usr/bin/env perl
use v5.14; use strict; use warnings;
use FindBin;
use lib $FindBin::Bin . "/../lib";

use Mailsheep::App;

use Getopt::Std;
use YAML;

use Encode qw(encode_utf8);
use Sereal::Encoder;

my %opts;
getopts('d:', \%opts);
binmode STDOUT, ":utf8";

my $app = Mailsheep::App->new(config_dir => "$ENV{HOME}/.config/mailsheep");

my $index_directory = $app->config->{index_dir};
mkdir( $index_directory ) unless -d $index_directory;

my $sereal = Sereal::Encoder->new;

for my $folder_name (@{ $app->config->{category} }) {
    my $idx = $app->index_folder($folder_name);
    $folder_name =~ s{\A(.*/)?([^/]+)\z}{$2};
    open my $fh, ">", File::Spec->catdir($index_directory, "${folder_name}.sereal");
    print $fh $sereal->encode($idx);
    close($fh);

    open $fh, ">", File::Spec->catdir($index_directory, "${folder_name}.yml");
    print $fh encode_utf8(YAML::Dump($idx));
    close($fh);
}
