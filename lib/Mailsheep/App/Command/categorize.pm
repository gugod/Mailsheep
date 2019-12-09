package Mailsheep::App::Command::categorize;
# ABSTRACT: classify and move mails to different mail folders.
use v5.14;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

sub opt_spec {
    return (
        [ "folder=s",  "Classify unread messages from this folder", { default => "INBOX" } ],
        [ "dry-run",   "Do not move the message, just display the result." ],
        [ "all-messages",   "Classify all messages instead of only unread ones" ],
        [ "explain",   "Explain the classifying process more verbosely." ],
    );
}

use Sereal::Decoder;
use Mailsheep::Categorizer;

use JSON;
my $JSON = JSON->new->pretty->canonical;

sub execute {
    my ($self, $opt) = @_;

    my $folder_name = $opt->{folder};

    my %count = ( processed => 0, classified => 0, classified_correctly => 0);

    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new( store => $index_directory );

    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";

    my %folder;
    my %is_auto;
    for my $folder (@{$self->config->{folders}}) {
        my $category = $folder->{name};
        next if $category eq $folder_name;
        $is_auto{$category} = $folder->{auto} ? 1 : 0;
        $folder{$category} = $mgr->open("=${category}",  access => "a") or die "The mail box \"=${category}\" does not exist\n";
    }

    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        next if $message->labels()->{seen} && !($opt->{all_message});

        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        my $mail_message_subject = $message->head->study("subject") // "";

        my $answer = $classifier->classify($doc);
        my $category = $answer->{category};

	if (!$category) {
            say(join("\t", "?", "???????", $mail_message_subject));
	} elsif ($category eq $folder_name) {
	    say(join("\t", "=", $category, $mail_message_subject));
	    $count{classified} += 1;
            $count{classified_correctly} += 1;
	} elsif (!$is_auto{$category}) {
	    say(join("\t", "~", $category, $mail_message_subject));
	    $count{classified} += 1;
	} else {
            my $f = $folder{$category};
            $mgr->moveMessage($f, $message) unless $opt->{dry_run};
            say(join("\t", "<", $category, $mail_message_subject));
            $count{classified} += 1;
	}

        if ($opt->{explain}) {
            say("\t" .$JSON->encode( $answer ) );
        }
	$count{processed} += 1;
    }

    say "Precision: $count{classified_correctly} / $count{processed} = " . ($count{classified_correctly} / $count{processed});
    say "Recall: $count{classified} / $count{processed} = " . ($count{classified} / $count{processed});
}

1;

no Moo;
__END__

mailsheep categorize =INBOX
