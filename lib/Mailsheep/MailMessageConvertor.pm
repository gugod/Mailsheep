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
        from_name  => [ map { $_->name    ||"" } $message->from   ],
        'list-id'  => [($message->head->study("List-Id")  // "").""],
        'reply-to' => [($message->head->study("reply-to") // "").""],
        to         => [ map { $_->address ||"" } $message->to     ],

        # 'return-path' => [($message->head->study("return-path") // "").""],
        # 'message-id'  => [($message->head->study("message-id") // "").""],
        # subject    => ($message->head->study("subject")  // "")."",
    };
}

sub convert_mail_message_to_analyzed_document {
    my ($self, $message) = @_;
    my $doc = $self->convert_mail_message_to_document($message);
    # s/\A.+(\@[^@]+)\z/$1/ for @{$doc->{'return-path'}};
    # s/\A.+(\@[^@]+)\z/$1/ for @{$doc->{'message-id'}};
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
    $doc2->{from} = $doc->{from};
    $doc2->{from_name} = $doc->{from_name};
    $doc2->{sender} = $doc->{sender};

    # my $doc2 = {%$doc};
    for my $fields (@{scalar cartesian { [$_[0], $_[1]] } (\@headers, \@headers)}) {
        next if $fields->[0] eq $fields->[1];
        if ( @{$doc->{$fields->[0]}} && @{$doc->{$fields->[1]}} ) {
            my $h = $fields->[0] . "," . $fields->[1];
            $doc2->{$h} //= [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{$fields->[0]}, $doc->{$fields->[1]}) }];
        }
    }
    return $doc2;
}

1;
