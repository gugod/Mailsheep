package Mailsheep::App;
use v5.14;
use Moo;
use Mailsheep::Analyzer;
use Mailsheep::Classifier;

use File::Spec::Functions qw(catfile);
use Encode qw(encode_utf8);
use Mail::Box::Manager;
use JSON;

has config_dir => (is => "ro", required => 1);
has config => (is => "lazy");

has mail_box_manager => ( is => "lazy" );

sub _build_mail_box_manager {
    my $self = shift;
    return Mail::Box::Manager->new( folderdir => $self->config->{maildir} ),
}

sub _build_config {
    my $self = shift;
    my $config_file = catfile($self->config_dir, "config.json");
    unless (-f $config_file) {
        die "config file $config_file does not exist.";        
    }

    open(my $fh, "<", $config_file) or die $!;
    local $/ = undef;
    my $config_text = <$fh>;
    close($fh);
    my $json = JSON->new;
    return $json->decode($config_text);
}

with 'Mailsheep::MailMessageConvertor';

sub train_with_old_messages {
    my ($self) = @_;
    my $index_directory = $self->config->{index_dir};
    mkdir( $index_directory ) unless -d $index_directory;

    my $classifier = Mailsheep::Classifier->new(
        store => $self->config->{index_dir}
    );

    for my $folder_name (@{ $self->config->{category} }) {
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
    }
}

sub categorize_new_messages {
    my ($self) = @_;

    my $classifier = Mailsheep::Classifier->new( store => $self->config->{index_dir} );

    my $mgr = $self->mail_box_manager;
    my $folder_inbox = $mgr->open("=INBOX", access => "rw") or die "INBOX does not exists\n";

    my %folder;

    for my $category (@{$self->config->{category}}) {
        $folder{$category} = $mgr->open("=${category}",  access => "a") or die "The mail box \"${category}\" does not exist\n";
    }

    my $count_message = $folder_inbox->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder_inbox->message($i);
        next if $message->labels()->{seen};
        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        if (my $category = $classifier->classify($doc)) {
            say encode_utf8( "$category\t<=\t" . ( $message->head->study("subject") // "") );
             $mgr->moveMessage($folder{$category}, $message);
        } else {
            say encode_utf8( "       \t<=\t" . ( $message->head->study("subject") // "") );
        }
    }
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

1;
