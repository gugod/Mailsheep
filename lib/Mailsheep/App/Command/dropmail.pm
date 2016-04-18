package Mailsheep::App::Command::dropmail;
# ABSTRACT: Drop a new mail to a folder.
use v5.14;
use Mailsheep::App -command;
use Moo; with(
    'Mailsheep::Role::Cmd',
);

use Time::Moment;

sub opt_spec {
    return (
        [ "folder=s",  "The folder name.", { default => "INBOX" } ],
        [ "body=s",  "The body of mail",   { default => 'No Body'} ],
        [ "subject=s",  "The subject of mail", { default => 'No Subject'} ],
    );
}

sub execute {
    my ($self, $opt) = @_;
    my $folder_name = $opt->{folder};

    my $folder = $self->mail_box_manager->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";

    my $m = Mail::Message->new(
        body => Mail::Message::Body::Lines->new(
            data => $opt->{body}
        ),
        head => Mail::Message::Head->build(
            Subject => $opt->{subject},
            From => 'nobody@localhost',
            To   => 'nobody@localhost',
            Date => Time::Moment->now_utc->strftime("%a, %d %b %Y %H:%M:%S GMT")
        )
    );
    $folder->addMessage($m);
    return;
}

1;
