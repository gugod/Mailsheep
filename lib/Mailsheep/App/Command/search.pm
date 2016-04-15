package Mailsheep::App::Command::search;
# ABSTRACT: search mails
use v5.14;
use strict;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageIterator',
);

sub opt_spec {
    return (
        [ "folder=s",  "Only this folder." ],
    );
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $query = join " ", @$args;
    $query = qr/$query/;

    $self->iterate_through_mails({
        ($opt->{folder} ? ( folder => $opt->{folder} ) : ())
    }, sub {
        my ($message) = @_;
        my $subject = $message->subject;
        if ($subject =~ /$query/i) {
            say $message->filename;
            say "\tSubject: $subject";
        }
    });
    
    return;
}


1;
