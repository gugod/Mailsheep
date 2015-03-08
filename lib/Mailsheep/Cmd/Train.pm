package Mailsheep::Cmd::Train;
use v5.12;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

use Parallel::ForkManager;
use Mailsheep::Categorizer;

sub execute {
    my ($self) = @_;
    my $index_directory = $self->xdg->data_home->subdir("index");
    mkdir( $index_directory ) unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new(store => $index_directory);

    my $forkman = Parallel::ForkManager->new(4);
    for my $folder (@{ $self->config->{folders} }) {
        $forkman->start and next;
        my $folder_name = $folder->{name};
        say $folder_name;
        my $folder = $self->mail_box_manager->open("=${folder_name}", access => "r");
        my $count_message = $folder->messages;

        my @documents;
        for my $i (0..$count_message-1) {
            my $message = $folder->message($i);
            next unless $message->label("seen");
            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            push @documents, $doc;
        }

        $classifier->train($folder_name, \@documents);
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
