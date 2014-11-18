package Mailsheep::MailMessageConvertor;
use v5.12;
use Moo::Role;
use Mailsheep::Analyzer;
use List::Gen ':modify';

sub convert_mail_message_to_document {
    my (undef, $message) = @_;
    return {
        sender     => [ map { $_->address ||"" } $message->sender ],
        from       => [ map { $_->address ||"" } $message->from   ],
        to         => [ map { $_->address ||"" } $message->to     ],
        # subject    => ($message->head->study("subject")  // "")."",
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
        'sender'   => $doc->{sender},
        'from'     => $doc->{from},
        # 'to'       => $doc->{to},
        (@{$doc->{to}} && @{$doc->{sender}}) ? (
            'sender,to'  => [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{sender}, $doc->{to}) }],
        ):(),
        (@{$doc->{to}} && @{$doc->{from}}) ? (
            'from,to'  => [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{from}, $doc->{to}) }],
        ):(),
        'list-id'  => [ $doc->{'list-id'} || () ],
        'reply-to' => [ $doc->{'reply-to'} || () ],
        'return-path' => [ $doc->{'return-path'} || () ]
    };
    # $doc2->{header_combined} = [ map { @$_ } values %$doc2 ];
    return $doc2;
}

1;
