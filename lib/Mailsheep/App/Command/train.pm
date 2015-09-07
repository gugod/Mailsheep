package Mailsheep::App::Command::train;
# ABSTRACT: Learn the classification rule with mails in folders.

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

use Parallel::ForkManager;
use Mailsheep::Categorizer;

sub execute {
    my ($self, $opt) = @_;
    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new(store => $index_directory);

    my @folders = $opt->{folder} ? ({ name => $opt->{folder} }) : (@{ $self->config->{folders} });
    my $forkman = Parallel::ForkManager->new(4);
    for my $folder (@folders) {
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
        $folder->close;
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

1;
