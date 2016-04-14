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

    $self->iterate_through_mails({
        ($opt->{folder} ? ( folder => $opt->{folder} ) : ())
    }, sub {
        my ($message) = @_;
        my $subject = $message->subject;
        say $subject if $subject =~ $query;
    });
    
    return;
}


1;
