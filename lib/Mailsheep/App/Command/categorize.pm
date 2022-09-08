package Mailsheep::App::Command::categorize;
# ABSTRACT: classify and move mails to different mail folders.
use v5.36;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

sub opt_spec {
    return (
        [ "folder=s",  "Classify unread messages from this folder", { default => "INBOX" } ],
        [ "dry-run",   "Do not move the message, just display the result." ],
        [ "all",       "Classify all messages instead of only unread ones" ],
        [ "explain",   "Explain the classifying process more verbosely." ],
        [ "quiet",   "Supress most of the output" ],
    );
}

use Sereal::Decoder;
use Mailsheep::Categorizer;
use JSON;

sub execute ($self, $pot) {
    my $folder_name = $opt->{folder};

    my %count = ( processed => 0, classified => 0, classified_correctly => 0);

    my $index_directory = $self->xdg->data_home->subdir("index");
    $index_directory->mkpath() unless -d $index_directory;

    my $classifier = Mailsheep::Categorizer->new( store => $index_directory );

    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";

    my %folder;
    my %is_auto;
    for my $category (@{$self->config->{categories}}) {
        my $category_name = $category->{name};
        next if $category_name eq $folder_name;

        $is_auto{$category_name} = $category->{auto} ? 1 : 0;

        my $f = ($category->{folders} && $category->{folders}[0]) ? $category->{folders}[0] : $category_name;
        $folder{$category_name} = $mgr->open("=$f",  access => "a") or die "The mail box \"=$f\" does not exist\n";
    }

    my $JSON = JSON->new->pretty->canonical;
    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        next if $message->labels()->{seen} && !($opt->{all});

        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        my $mail_message_subject = $message->head->study("subject") // "";

        my $answer = $classifier->classify($doc);
        my $category = $answer->{category};

	if (!$category) {
            say(join("\t", "?", "???????", $mail_message_subject)) unless $opt->{quiet};
	} elsif ($category eq $folder_name) {
	    say(join("\t", "=", $category, $mail_message_subject)) unless $opt->{quiet};
	    $count{classified} += 1;
            $count{classified_correctly} += 1;
	} elsif (!$is_auto{$category}) {
	    say(join("\t", "~", $category, $mail_message_subject)) unless $opt->{quiet};
	    $count{classified} += 1;
	} else {
            my $f = $folder{$category};
            $mgr->moveMessage($f, $message) unless $opt->{dry_run};
            say(join("\t", "<", $category, $mail_message_subject)) unless $opt->{quiet};
            $count{classified} += 1;
	}

        if ($opt->{explain}) {
            say("\t" .$JSON->encode( $answer ) );
        }
	$count{processed} += 1;
    }

    if ($count{processed}) {
        say "Precision: $count{classified_correctly} / $count{processed} = " . ($count{classified_correctly} / $count{processed});
        say "Recall: $count{classified} / $count{processed} = " . ($count{classified} / $count{processed});
    } else {
        say "Nohting is processed.";
    }
}

1;

no Moo;
__END__

mailsheep categorize =INBOX
