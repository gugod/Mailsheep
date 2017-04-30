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
        [ "workers=n",  "The number of worker process to fork" ],
        [ "folder=s",  "Only train this folder" ],
        [ "with-feature-aggregator", "Train with the 'FeatureAggregator' trainer"],
    );
}

use Parallel::ForkManager;

use Mailsheep::FeatureAggregator;
use Mailsheep::Categorizer;

sub train_with_feature_aggregator {
    my ($self, $opt) = @_;
    my $store = $self->xdg->data_home->subdir("features");
    $store->mkpath() unless -d $store;

    my $trainer = Mailsheep::FeatureAggregator->new(store => $store);

    my @folders = $opt->{folder} ? ({ name => $opt->{folder} }) : (@{ $self->config->{folders} });
    for my $folder (@folders) {
        my $folder_name = $folder->{name};
        say $folder_name;

        my $folder = $self->mail_box_manager->open("=${folder_name}", access => "r");
        my $count_message = $folder->messages;

        my @documents;
        for my $i (0..$count_message-1) {
            my $message = $folder->message($i);
            next unless $message->label("seen");

            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            my @features = map { my $f = $_; (map { join("\t", $f, $_) } @{$doc->{$_}}) } keys %$doc;

            $trainer->feed( $folder_name, \@features );
        }

        $self->mail_box_manager->close($folder);
    }

    $trainer->save;
}

sub execute {
    my ($self, $opt) = @_;

    if ($opt->{with_feature_aggregator}) {
        say "Training with FeatureAggregator";
        $self->train_with_feature_aggregator($opt);
        return;
    }

    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new(store => $index_directory);

    my @folders = $opt->{folder} ? ({ name => $opt->{folder} }) : (@{ $self->config->{folders} });
    my $forkman = Parallel::ForkManager->new( $opt->{workers} ||1 );
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
