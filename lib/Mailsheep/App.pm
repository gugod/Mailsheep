package Mailsheep::App;
use v5.12;
use Moo;
use MooX::Options;

use Mailsheep::Analyzer;
use Mailsheep::Categorizer;

use File::XDG;
use File::Spec::Functions qw(catfile);
use Encode qw(encode_utf8);
use Mail::Box::Manager;
use JSON;
use Parallel::ForkManager;

with 'Mailsheep::MailMessageConvertor';

sub train_with_old_messages {
    my ($self) = @_;
    my $index_directory = $self->config->{index_dir};
    mkdir( $index_directory ) unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new(
        store => $self->config->{index_dir}
    );

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
            next unless $message->labels()->{seen};
            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            push @documents, $doc;
        }

        $classifier->train($folder_name, \@documents);
        $forkman->finish;
    }
    $forkman->wait_all_children;
}

sub subject_frequency {
    my $self = shift;
    my $box  = shift;

    my %seen;
    my $folder = $self->mail_box_manager->open("=${box}", access => "r");
    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        # next if $message->labels()->{seen};
        my $subject = $message->head->study("subject") // "";
        $seen{$subject}++;
    }

    return \%seen;
}


sub date_histogram {
    my $self = shift;
    my $now = time;

    my $interval = 7;

    for my $folder_config (@{ $self->config->{folders} }) {
        my $name = $folder_config->{name};
        my $retention = $folder_config->{retention} or next;

        my $folder = $self->mail_box_manager->open("=${name}", access => "r");
        my $count_message = $folder->messages;

        my $earliest_timestamp = time;
        my %bucket;
        my @documents;
        for my $i (0..$count_message-1) {
            my $message = $folder->message($i);
            my $delta_days = int(($now - $message->timestamp())/86400);
            my $delta_interval = int($delta_days / $interval);
            $bucket{$delta_interval}++;

            $earliest_timestamp = $message->timestamp() if $message->timestamp() < $earliest_timestamp;
        }
        $folder->close;

        my @v;
        my $t = $now;
        while($t >= $earliest_timestamp) {
            my $k = int($t/$interval);
            push @v, [$k, $bucket{$k} //0];
            $t -= $interval*86400;
        }

        use Data::Dumper;
        print Data::Dumper::Dumper([$name, \%bucket]);
    }
}

1;
