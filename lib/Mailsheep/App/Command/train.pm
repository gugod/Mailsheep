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

sub opt_spec {
    return (
        [ "workers=n",  "The number of worker process to fork" ],
        [ "folder=s",  "Only train this folder" ]
    );
}

sub execute {
    my ($self, $opt) = @_;
    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    $self->build_feature_index;
    $self->remove_noise_features;
    $self->write_feature_index;
    return;
}

sub build_feature_index {
    my ($self) = @_;
    my $mgr = $self->mail_box_manager;

    my %features;
    my %folder_messages;
    for (@{$self->config->{folders}}) {
        my $name = $_->{name};
        my $folder = $mgr->open("=${name}", access => "r", remove_when_empty => 0) or die "$name does not exists\n";

        my $count_message = $folder_messages{$name} =  $folder->messages;
        for (my $i = 0; $i < $count_message; $i++) {
            my $message = $folder->message($i);
            next unless $message->labels()->{seen};

            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            for my $k (keys %$doc) {
                for my $v (@{ $doc->{$k} }) {
                    my $fk = "$k\t=\t$v";
                    $features{$fk}{total}++;
                    $features{$fk}{by_folder}{$name}++;
                    $features{$fk}{by_field}{$k}++;
                    $features{$fk}{by_folder_and_feature}{"$name\t$fk"}++;
                }
            }
        }
        $folder->close;
    }
    $self->{features} = \%features;
    $self->{folder_messages} = \%folder_messages;
}

sub remove_noise_features {
    my ($self) = @_;

    my $features = $self->{features};

    my $threshold = int(@{$self->config->{folders}} * 0.5);

    for my $fk (keys %$features) {
        my $c = keys %{$features->{$fk}{by_folder}};
        next if ($c < $threshold);
        delete $features->{$fk};
    }
}

sub write_feature_index {
    my ($self, $opt) = @_;

    my $index_directory = $self->xdg->data_home->subdir("index")->subdir("features");
    $index_directory->mkpath;

    my $content = {
        features => $self->{features},
        folder_messages => $self->{folder_messages},
    };

    my $ts = time;
    my $sereal = Sereal::Encoder->new;
    open my $fh, ">", $index_directory->file("features.${ts}.sereal");
    print $fh $sereal->encode($content);
    close($fh);
}

1;
