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

my $index_directory = $opts{d} or die "-d /dir/of/index";
mkdir( $index_directory ) unless -d $index_directory;

my $app = Mailsheep::App->new(
    maildir => "$ENV{HOME}/Maildir/",
    indexdir => $opts{d},
);

my $sereal = Sereal::Encoder->new;

for my $folder_name (@ARGV) {
    my $idx = $app->index_folder($folder_name);
    
    $folder_name =~ s{\A(.*/)?([^/]+)\z}{$2};
    open my $fh, ">", File::Spec->catdir($index_directory, "${folder_name}.sereal");
    print $fh $sereal->encode($idx);
    close($fh);

    open $fh, ">", File::Spec->catdir($index_directory, "${folder_name}.yml");
    print $fh encode_utf8(YAML::Dump($idx));
    close($fh);
}
