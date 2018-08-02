package Mailsheep::App::Command::mr;
# ABSTRACT: do map-reduce
use v5.14;
use strict;
use warnings;

use JSON;
use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageIterator',
);

sub opt_spec {
    return (
        [ "e=s",  "Callback code that does some aggregation" ],
        [ "folder=s",  "Only this folder." ],
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    unless (defined($opt->{e})) {
        die "Callback is required";
    }

    my $o = $self->do_map_reduce($opt, $args);
    print JSON->new->utf8->pretty->canonical->encode($o);
}

sub do_map_reduce {
    my ($self, $opt, $args) = @_;

    my %STATS;
    $self->iterate_through_mails({
        $opt->{folder} ? ( folder => $opt->{folder} ) : (),
    }, sub {
        my ($m) = @_;
        my $sender = $m->sender;
        my (@from) = $m->from;
        my (@to)   = $m->to;
        eval "$opt->{e}; 1" or die $@;
    });

    return {
        stats => \%STATS
    };
}

no Moo;
1;

