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
        [ "all-message",   "Classify all messages instead of only unread ones" ],
        [ "explain",   "Explain the classifying process more verbosely." ],
    );
}

use File::Slurp qw(read_file);
use Sereal::Decoder;

use JSON;
my $JSON = JSON->new->canonical;

sub execute {
    my ($self, $opt) = @_;
    my $folder_name = $opt->{folder};

    my $index_directory = $self->xdg->data_home->subdir("index")->subdir("features");

    my $sereal = Sereal::Decoder->new;
    my ($fn) = sort { $b cmp $a } <${index_directory}/features.*.sereal>;
    my $x = read_file($fn);
    my $idx = $sereal->decode($x);
    my $features = $idx->{features};
    my $folder_messages = $idx->{folder_messages};

    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "=$folder_name does not exist\n";

    my %folder;
    for (@{$self->config->{folders}}) {
        my $category = $_->{name};
        next if $category eq $folder_name;
        $folder{$category} = $mgr->open("=${category}",  access => "a", remove_when_empty => 0) or die "The mail box \"=${category}\" does not exist\n";
    }

    say "$folder === $folder_name";
    my $count_message = $folder->messages;
    for my $i (0.. $count_message-1) {
        my $message = $folder->message($i);
        next if $message->labels()->{seen} && !($opt->{all_message});

        my $mail_message_subject = $message->head->study("subject") // "";

        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        my %votes;
        my $unknowns = 0;
        my $knowns;
        for my $k (keys %$doc) {
            for my $v (@{$doc->{$k}}) {
                my $fk = "$k\t=\t$v";
                if (exists $features->{$fk}) {
                    my $f_total = $features->{$fk}{total};
                    my $f_by_folder = $features->{$fk}{by_folder};
                    my $f_by_folder_and_feature = $features->{$fk}{by_folder_and_feature};

                    my %v;
                    for my $folder (keys %$f_by_folder ) {
                        $v{$folder} = ($f_by_folder_and_feature->{"$folder\t$fk"} //0) / $f_total;
                    }
                    my ($x) =  sort { $v{$b} <=> $v{$a} } keys %v;
                    $votes{$x} += 1;
                    $knowns++;
                } else {
                    $unknowns++;
                }
            }
        }
        if (keys %votes == 1 || (keys %votes > 0 && $unknowns < $knowns)) {
            my $f;
            my $op = "=";
            my ($category) = sort { $votes{$b} <=> $votes{$a} } keys %votes;
            if ($category && $category ne $folder_name && ($f = $folder{$category})) {
                $mgr->moveMessage($f, $message) unless $opt->{dry_run};
                $op = "<";
            }
            # say "\tUnknown: $unknowns, Known: $knowns";
            say(join("\t", $category // "???", $op, $mail_message_subject, $JSON->encode(\%votes) ));
        } else {
            say(join("\t", "???", "=", $mail_message_subject, $JSON->encode(\%votes) ));
        }
    }
}

1;

__END__

mailsheep categorize =INBOX
