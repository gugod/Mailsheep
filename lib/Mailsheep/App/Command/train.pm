package Mailsheep::App::Command::train;
# ABSTRACT: Learn the classification rule with mails in folders.

use v5.14;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

use Sereal::Encoder;
use Sereal::Decoder;

sub opt_spec {
    return (
        [ "workers=n",  "The number of worker process to fork" ],
        [ "folder=s",  "Only train this folder" ]
    );
}

use Parallel::ForkManager;
use Mailsheep::Categorizer;

sub execute {
    my ($self, $opt) = @_;
    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    $self->build_feature_index;
    $self->remove_noise_features;
    $self->write_feature_index;

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

sub build_feature_index {
    my ($self) = @_;
    my $mgr = $self->mail_box_manager;

    my %features;
    for (@{$self->config->{folders}}) {
        my $name = $_->{name};
        my $folder = $mgr->open("=${name}", access => "r", remove_when_empty => 0) or die "$name does not exists\n";

        my $count_message = $folder->messages;
        for (my $i = 0; $i < $count_message; $i++) {
            my $message = $folder->message($i);
            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            for my $k (keys %$doc) {
                for my $v (@{ $doc->{$k} }) {
                    my $fk = "$k\t=\t$v";
                    $features{$fk}{total}++;
                    $features{$fk}{by_folder}{$name}++;
                }
            }
        }
        $folder->close;
    }
    $self->{features} = \%features;
}

sub remove_noise_features {
    my ($self) = @_;

    my $features = $self->{features};

    my $threshold = int(@{$self->config->{folders}} * 0.4);

    for my $fk (keys %$features) {
        my $f = $features->{$fk}{total};
        my $c = keys %{$features->{$fk}{by_folder}};
        next if $f > 1 && ($c < $threshold);
        delete $features->{$fk};
    }
}

sub write_feature_index {
    my ($self, $opt) = @_;

    my $index_directory = $self->xdg->data_home->subdir("index")->subdir("features");
    $index_directory->mkpath;

    my $features = $self->{features};

    my $ts = time;
    my $sereal = Sereal::Encoder->new;
    open my $fh, ">", $index_directory->file("features.${ts}.sereal");
    print $fh $sereal->encode($features);
    close($fh);
}

1;
