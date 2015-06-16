package Mailsheep::App::Command::readall;
use v5.12;
use Mailsheep::App -command;
use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

sub opt_spec {
    return (
        [ "folder=s",  "The folder name." ]
    );
}

sub execute {
    my ($self, $opt) = @_;
    my $folder_name = $opt->{folder};

    my $folder = $self->mail_box_manager->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";
    $folder->acceptMessages();

    my $count_message = $folder->messages('ALL');
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        next if $message->label('seen');
        $message->label(seen => 1);
        say "autoread: " . $message->head->study("subject");
    }
    $folder->close;
}

1;
