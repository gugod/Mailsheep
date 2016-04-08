package Mailsheep::App::Command::jsonify;
# ABSTRACT: do map-reduce
use v5.14;
use strict;
use warnings;

use JSON;
use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor',
);

sub opt_spec {
    return (
        [ "e=s",  "Callback code that does some aggregation" ],
        [ "folder=s",  "Only this folder." ],
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    $self->do_map_reduce($opt, $args);
    return;
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

    my $JSON = JSON->new->pretty->canonical;
    for (values %folder) {
        for my $m ($_->messages) {
            my $doc = $self->convert_mail_message_to_simple_document($m);
            say $JSON->encode($doc);
        }
    }
    return;
}

1;

