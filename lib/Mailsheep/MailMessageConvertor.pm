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
        # 'return-path' => [($message->head->study("return-path") // "").""],
        # 'message-id'  => [($message->head->study("message-id") // "").""],
        # 'reply-to' => [($message->head->study("reply-to") // "").""],

        'delivered-to' => [($message->head->study("delivered-to") // "").""],
        'from.name' => [ (map { ($_->name||"") } $message->from) ],
        fromish => [
            uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } (
                (map { ($_->address ||"",  $_->name||"" ) } $message->from),
                (map { $_->address ||"" } $message->sender),
            )
        ],
        'list-id'  => [(($message->head->study("List-Id") // "")."")],

        'to.name'    => [ map { $_->name    ||"" } $message->to ],
        'to.address' => [ map { $_->address ||"" } $message->to ],

        subject    => [ ($message->head->study("subject")  // "")."" ],
    };

    for my $subject (@{$doc->{subject}}) {
        my @t = Mailsheep::Analyzer::standard($subject);
        push @{$doc->{subject_shingle5}}, Mailsheep::Analyzer::sorted_shingle(5, @t);
    }
    $doc->{subject_shingle5} = [uniq(@{$doc->{subject_shingle5}})];

    my @received = map {
        my @tok = split(/(\Afrom|by|with|for|;)/, $_);
        shift @tok;
        +{ @tok, _raw => "$_" };
    } $message->head->get("Received");

    $doc->{"received.from"} = [ uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } map { $_->{from} } @received ];

    $doc->{"delivered-to eq to.address"} = [ "false" ];
    for my $d0 (@{ $doc->{"delivered-to"} }) {
        for my $d1 (@{ $doc->{"to.address"} }) {
            if ($d0 eq $d1) {
                $doc->{"delivered-to eq to.address"} = [ "true" ];
                last;
            }
        }
        last if ($doc->{"delivered-to eq to.address"}[0] eq "true");
    }

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

    # for my $h ("to.name", "subject") {
    #     $doc->{"$h is empty"} = [ exists($doc->{$h}) ? "false" : "true" ];
    # }

    if ($doc->{'to.name'} &&  $doc->{'delivered-to'}) {
        $doc->{'to.name + delivered-to'} = [
            $doc->{'to.name'}[0] . ' ' . $doc->{'delivered-to'}[0]
        ];
    }

    delete $doc->{subject};
    delete $doc->{'delivered-to'};
    delete $doc->{'to.address'};

    my @headers = keys %$doc;
    my $doc2 = {};
    for my $fields (@{scalar cartesian { [ sort ($_[0], $_[1]) ] } (\@headers, \@headers)}) {
        next if $fields->[0] eq $fields->[1];
        if ( @{$doc->{$fields->[0]}} && @{$doc->{$fields->[1]}} ) {
            my $h = $fields->[0] . "," . $fields->[1];
            next if $doc2->{$h};
            $doc2->{$h} //= [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{$fields->[0]}, $doc->{$fields->[1]}) }];
        }
    }
    delete @{$doc2}{@headers};
    $doc2->{subject_shingle5} = $doc->{subject_shingle5};
    return $doc2;
}

1;
