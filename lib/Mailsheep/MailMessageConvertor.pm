package Mailsheep::MailMessageConvertor;
use v5.14;
use Moo::Role;

sub convert_mail_message_to_hash {
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

1;
