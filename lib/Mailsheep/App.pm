package Mailsheep::App;
use v5.14;
use Moo;
use Mailsheep::Analyzer;
use Mailsheep::MessageOrganizer;

use File::Spec::Functions qw(catfile);
use Encode qw(encode_utf8);
use Digest::SHA1 qw(sha1_hex);
use File::Basename qw(basename);
use Mail::Box::Manager;

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

sub index_folder {
    my $self = shift;
    my $box  = shift;

    my $box_idx  = {};

    my $folder = $self->mail_box_manager->open("=${box}", access => "r");
    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        next unless $message->labels()->{seen};

        my $doc = $self->convert_mail_message_to_hash( $message );
        index_document($box_idx, $doc);
    }

    return $box_idx;
}

sub index_document {
    my ($idx, $doc) = @_;

    $idx->{df}++;
    for my $field (keys %$doc) {
        my $fidx = $idx->{field}{$field} ||= {};

        my $v = Mailsheep::Analyzer::filter_characters($doc->{$field});

        my @tokens = ($v, Mailsheep::Analyzer::standard($v));

        $fidx->{tf} += @tokens;
        $idx->{tf}  += @tokens;

        my %seen;
        for my $token (@tokens) {
            $fidx->{token}{$token}{tf}++;
            $seen{$token}++;
        }

        $fidx->{count_utoken} += keys %seen;
        for my $token (keys %seen) {
            $fidx->{token}{$token}{df}++;
        }
    }
}

sub categorize_new_messages {
    my ($self) = @_;

    my $idx = $self->load_indices();
    my $mo  = Mailsheep::MessageOrganizer->new( idx => $idx );

    my $mgr = $self->mail_box_manager;
    my $folder_inbox = $mgr->open("=INBOX", access => "rw");

    my %folder;
    for my $category (keys %$idx) {
        $folder{$category} = $mgr->open("=${category}",  access => "a");
    }

    my $count_message = $folder_inbox->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder_inbox->message($i);
        next if $message->labels()->{seen};
        
        my $doc = $self->convert_mail_message_to_hash( $message );
        my $message_str = eval { $message->string(); };
        next if $@;

        if (my $category = $mo->looks_like( $doc )) {
            say encode_utf8("$i\t$category\t<= $doc->{subject}");
            $mgr->moveMessage($folder{$category}, $message);
        } else {
            say encode_utf8("$i\t       \t<= $doc->{subject}");
        }
    }
}

sub load_indices {
    my ($self) = @_;
    my $index_directory = $self->config->{index_dir};
    my $idx = {};
    my $sereal = Sereal::Decoder->new;
    for my $fn (<$index_directory/*.sereal>) {
        my $box_name = basename($fn) =~ s/\.sereal$//r;
        next if lc($box_name) eq 'inbox';
        open my $fh, "<", $fn;
        local $/ = undef;
        $idx->{$box_name} = $sereal->decode(<$fh>);
    }
    return $idx;
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
