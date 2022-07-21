package Mailsheep::App::Command::jsonify;
# ABSTRACT: Convert mail messages to JSON stream.
use v5.36;

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
        [ "pretty", "Print pretty JSON instead." ],
    );
}

sub execute ($self, $opt, $args) {
    my $JSON = JSON->new->canonical;
    $JSON->pretty(1) if $opt->{pretty};

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

