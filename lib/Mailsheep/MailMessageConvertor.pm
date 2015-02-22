package Mailsheep::MailMessageConvertor;
use v5.12;
use Moo::Role;
use Mailsheep::Analyzer;
use List::Gen ':modify';
use List::MoreUtils 'uniq';

sub convert_mail_message_to_analyzed_document {
    my ($self, $message) = @_;
    my $doc = {
        'reply-to' => [($message->head->study("reply-to") // "").""],
        'list-id'  => [(($message->head->study("List-Id") // "")."")],

        'from.name' => [ (map { ($_->name||"") } $message->from) ],
        fromish => [
            uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } (
                (map { ($_->address ||"",  $_->name||"" ) } $message->from),
                (map { $_->address ||"" } $message->sender),
            )
        ],

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
    for my $fields (@{scalar cartesian { [ sort ($_[0], $_[1]) ] } (\@headers, \@headers)}) {
        next if $fields->[0] eq $fields->[1];
        next if $fields->[0] eq 'to.address' && $fields->[1] eq 'to.name';
        next if $fields->[1] eq 'to.address' && $fields->[0] eq 'to.name';
        if ( @{$doc->{$fields->[0]}} && @{$doc->{$fields->[1]}} ) {
            my $ha = $fields->[0] . "," . $fields->[1];
            my $hb = $fields->[1] . "," . $fields->[0];
            next if $doc2->{$ha} || $doc2->{$hb};
            $doc2->{$ha} //= [@{ scalar cartesian { $_[0] . " " . $_[1] } ($doc->{$fields->[0]}, $doc->{$fields->[1]}) }];
        }
    }
    return $doc2;
}

1;
