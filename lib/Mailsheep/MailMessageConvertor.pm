package Mailsheep::MailMessageConvertor;
use v5.14;
use Moo::Role;
use Mailsheep::Analyzer;

sub convert_mail_message_to_document {
    my (undef, $message) = @_;
    return {
        from       => join(" ", map({ $_->address } $message->from)),
        subject    => ($message->head->study("subject")  // "")."",
        'list-id'  => ($message->head->study("List-Id")  // "")."",
        'reply-to' => ($message->head->study("reply-to") // "")."",
        'message-id'  => ($message->head->study("message-id") // "")."",
        'return-path' => ($message->head->study("return-path") // "")."",
    };
}

sub convert_mail_message_to_analyzed_document {
    my ($self, $message) = @_;
    my $doc = $self->convert_mail_message_to_document($message);
    return {
        from => [ $doc->{from} || () ],
        'list-id' => [ $doc->{'list-id'} || () ],
        'reply-to' => [ $doc->{'reply-to'} || () ],
        header => [ grep { $_ } (
            $doc->{from},
            $doc->{'reply-to'},
            Mailsheep::Analyzer::standard( Mailsheep::Analyzer::filter_characters( $doc->{subject} ) ),
        )]
    };
}

1;
