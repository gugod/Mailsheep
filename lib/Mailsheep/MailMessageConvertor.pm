package Mailsheep::MailMessageConvertor;
use v5.12;
use Moo::Role;
use Mailsheep::Analyzer;
use List::Gen ':modify';
use List::MoreUtils 'uniq';

sub convert_mail_message_to_analyzed_document {
    my ($self, $message) = @_;
    my $doc = {
        # sender     => [ map { $_->address ||"" } $message->sender ],
        fromish => [
            uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } (
                (map { ($_->address ||"",  $_->name||"" ) } $message->from),
                (map { $_->address ||"" } $message->sender),
            )
        ],
        'list-id' => [(($message->head->study("List-Id")  // "")."")],
        'reply-to' => [($message->head->study("reply-to") // "").""],
        # to         => [ map { $_->address ||"" } $message->to     ],
        # 'return-path' => [($message->head->study("return-path") // "").""],
        # 'message-id'  => [($message->head->study("message-id") // "").""],
        subject    => [ ($message->head->study("subject")  // "")."" ],
    };

    my @received = map {
        my @tok = split(/(\Afrom|by|with|for|;)/, $_);
        shift @tok;
        +{ @tok, _raw => "$_" };
    } $message->head->get("Received");

    $doc->{"received.from"} = [ uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } map { $_->{from} } @received ];

    for my $h (keys %$doc) {
        for (@{$doc->{$h}}) {
            s/\s+/ /g;
            s/\A\s//;
            s/\s\z//;            
        }
        @{$doc->{$h}} = grep { $_ ne '' } @{$doc->{$h}};
        if (@{$doc->{$h}} == 0) {
            delete $doc->{$h};
        }
    }

    my @headers = keys %$doc;
    my $doc2 = {};
    for my $fields (@{scalar cartesian { [$_[0], $_[1]] } (\@headers, \@headers)}) {
        next if $fields->[0] eq $fields->[1];
        if ( @{$doc->{$fields->[0]}} && @{$doc->{$fields->[1]}} ) {
            my $h = $fields->[0] . "," . $fields->[1];
            $doc2->{$h} //= [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{$fields->[0]}, $doc->{$fields->[1]}) }];
        }
    }
    delete @{$doc2}{@headers};
    return $doc2;
}

1;
