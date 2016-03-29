package Mailsheep::App::Command::features;
use v5.14;
use strict;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

use JSON;
use POSIX qw(floor);

sub min {
    my ($a,$b) = @_;
    return ($a < $b) ? $a : $b;
}

sub opt_spec {
    return (
        [ "folder=s",  "The folder." ],
        [ "threshold=n",  "Threshold", { default => 0.9 } ],
    );
}

my $JSON = JSON->new->pretty;

sub execute {
    my ($self, $opt) = @_;
    my ($folder_name);
    unless (defined($folder_name = $opt->{folder})) {
        die "folder is required";
    }
    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";
    my $count_message = $folder->messages;
    my %features;
    for (my $i = 0; $i < $count_message; $i++) {
        my $message = $folder->message($i);
        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        for my $k (keys %$doc) {
            for my $v (@{ $doc->{$k} }) {
                my $fk = "$k\t=\t$v";
                $features{$fk}++;
            }
        }
    }

    my $threshold = ($opt->{threshold} > 1) ? $opt->{threshold} : ($count_message * $opt->{threshold});
    my @fk = sort { $features{$b} <=> $features{$a} } grep { $features{$_} > 2 } keys %features;

    my $bound= 0;
    while ($features{$fk[$bound]} >= $threshold) {
        $bound++;
    }
    if ( $bound == 0 ) {
        $bound = min(0.1*@fk, 25);
    }

    for (my $i = 0; $i < $bound; $i++) {
        my $k = $fk[$i];
        printf("%2.2f\t%d\t%d\t\t%s\n", $features{$k} / $count_message, $features{$k}, $count_message, $k);
    }
}

1;
