package Mailsheep::App::Command::jsonify;
# ABSTRACT: Convert mail messages to JSON stream.
use v5.14;
use strict;
use warnings;

use JSON;
use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor',
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

    my $JSON = JSON->new->pretty->canonical;
    $self->iterate_through_mails({
        $opt->{folder} ? ( folder => $opt->{folder} ) : (),
    }, sub {
        my ($m) = @_;
        my $doc = $self->convert_mail_message_to_simple_document($m);
        say $JSON->encode($doc);
    });

    return;
}

no Moo;
1;

