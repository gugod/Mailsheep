package Mailsheep::App::Command::mr;
# ABSTRACT: do map-reduce
use v5.14;
use strict;
use warnings;

use JSON;
use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
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

    my $mgr = $self->mail_box_manager;
    my %folder;
    if ($opt->{folder}) {
        $folder{$opt->{folder}} = $mgr->open("=$opt->{folder}",  access => "r") or die "The mail box \"=$opt->{folder}\" cannot be opened.\n";
    } else {
        for my $folder (@{$self->config->{folders}}) {
            my $x = $folder->{name};
            $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
        }
    }

    my %STATS;
    for (values %folder) {
        for my $m ($_->messages) {
            my $sender = $m->sender;
            my (@from) = $m->from;
            my (@to)   = $m->to;
            eval "$opt->{e}; 1" or die $@;
        }
    }
    return {
        stats => \%STATS
    };
}

1;

