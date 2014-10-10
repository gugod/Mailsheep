package Mailsheep::Cmd::Categorize;
use v5.12;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

use Encode 'encode_utf8';
use Mailsheep::Categorizer;


has folder => (is => "ro", default => sub { "INBOX" });

has dry_run => ( is => "ro", default => 0 );

sub execute {
    my ($self) = @_;

    my $folder_name = $self->folder;

    my $classifier = Mailsheep::Categorizer->new( store => $self->config->{index_dir} );

    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "rw", remove_when_empty => 0) or die "$folder_name does not exists\n";

    my %folder;

    for my $folder (@{$self->config->{folders}}) {
        my $category = $folder->{name};
        next if $category eq $folder_name;
        $folder{$category} = $mgr->open("=${category}",  access => "a") or die "The mail box \"=${category}\" does not exist\n";
    }

    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);

        my $doc = $self->convert_mail_message_to_analyzed_document( $message );
        my $mail_message_subject = $message->head->study("subject") // "";

        my $answer = $classifier->classify($doc);
        if (my $category = $answer->{category}) {
            if ($category eq $folder_name) {
                say encode_utf8(join("\t", $category, "==", $answer->{guess}[0]{field}, $mail_message_subject));
            } else {
                $mgr->moveMessage($folder{$category}, $message) unless $self->dry_run;
                say encode_utf8(join("\t", $category, "<=", $answer->{guess}[0]{field}, $mail_message_subject));
            }
        } else {
            say encode_utf8(join("\t","(????)", "<=", "(????)", $mail_message_subject));
        }
    }
}

1;

__END__

mailsheep categorize =INBOX
