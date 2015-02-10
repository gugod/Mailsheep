package Mailsheep::Cmd::ReadAll;

use v5.12;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

has folder => (is => "ro", required => 1);

sub execute {
    my $self = shift;
    my $folder_name = $self->folder;

    my $folder = $self->mail_box_manager->open("=${folder_name}", access => "rw", remove_when_empty => 0);
    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        next if $message->label('seen');
        $message->label(seen => 1);
        say "auto-READ: " . $message->head->study("subject");
    }
    $folder->close;
}

1;
