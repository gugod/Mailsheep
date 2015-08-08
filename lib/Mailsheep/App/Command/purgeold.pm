package Mailsheep::App::Command::purgeold;
# ABSTRACT: remove mails older than retention period of its folder
use v5.14;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

sub opt_spec {
    return (
        [ "folder=s",  "Only train this folder" ]
    );
}

sub execute {
    my ($self, $opt) = @_;
    my $now = time;

    my @folders = @{ $self->config->{folders} };
    if (defined($opt->{folder})) {
        @folders = grep { $_->{name} eq $opt->{folder} } @folders;
    }

    for my $folder_config (@folders) {
        my $name = $folder_config->{name};
        my $retention = $folder_config->{retention} or next;

        my $folder = $self->mail_box_manager->open("=${name}", access => "rw", remove_when_empty => 0);
        my $count_message = $folder->messages;

        my @documents;
        for my $i (0..$count_message-1) {
            my $message = $folder->message($i);
            next unless $message->label("seen") && !$message->label("flagged");
            my $delta_days = int(($now - $message->timestamp())/86400);
            if ($delta_days > $retention) {
                say "DELETE: " . $folder->name . " " . $message->subject;
                $message->delete;
            }
        }
        $folder->close;
    }
}

1;
