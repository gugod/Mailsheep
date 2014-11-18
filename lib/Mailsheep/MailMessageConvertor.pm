package Mailsheep::MailMessageConvertor;
use v5.12;
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
    my $doc2 = {
        'from'     => [ $doc->{from} || () ],
        'list-id'  => [ $doc->{'list-id'} || () ],
        'reply-to' => [ $doc->{'reply-to'} || () ],
        'return-path' => [ $doc->{'return-path'} || () ]
    };
    $doc2->{header_combined} = [ map { @$_ } values %$doc2 ];
    return $doc2;
}

1;
