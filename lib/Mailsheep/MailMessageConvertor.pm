package Mailsheep::MailMessageConvertor;
use v5.18;
use Moo::Role;
use Mailsheep::Analyzer;
use List::Gen ':modify';
use List::MoreUtils 'uniq';

sub convert_mail_message_to_simple_document {
    my ($self, $message) = @_;
    my $doc = {
        'reply-to' => [($message->head->study("reply-to") // "").""],
        'list-id'  => [(($message->head->study("List-Id") // "")."")],
        'from'   => [ map { $_->format } $message->from ] ,
        'sender' => [ map { $_->format } $message->sender ] ,
        'to'     => [ map { $_->format } $message->to ],
        subject  => [ ($message->head->study("subject")  // "")."" ],
        'body' => [ "". $message->body->decoded ],
    };

    for my $h (keys %$doc) {
        @{$doc->{$h}} = grep { $_ ne '' } @{$doc->{$h}};
        if (@{$doc->{$h}} == 0) {
            delete $doc->{$h};
        }
    }

    return $doc;
}

sub convert_mail_message_to_analyzed_document {
    my ($self, $message) = @_;
    my $doc = {
        'reply-to' => [($message->head->study("reply-to") // "").""],
        'list-id'  => [(($message->head->study("List-Id") // "")."")],

        fromish => [
            uniq (
                $message->head->get("From"),
                (map { ($_->name||"") ."_". ($_->address||"") } $message->from),
                (map { ($_->name||"") ."_". ($_->address||"") } $message->sender),
            )
        ],

        'to'     => [ map { ($_->name||"") ."_". ($_->address||"") } $message->to ],
        subject  => [ ($message->head->study("subject")  // "")."" ],
        '!date'  => [ (! $message->head->get("Date")) ],
    };

    for my $subject (@{$doc->{subject}}) {
        my @t = Mailsheep::Analyzer::standard($subject);
        push @{$doc->{subject_shingle}}, Mailsheep::Analyzer::shingle(3, @t);
    }
    $doc->{subject_shingle} = [uniq(map { fc($_) } @{$doc->{subject_shingle}})];

    my @received = map {
        my @tok = split(/(\Afrom|by|with|for|;)/, $_);
        shift @tok;
        +{ @tok, _raw => "$_" };
    } $message->head->get("Received");

    $doc->{"received.from"} = [ uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } map { $_->{from} } @received ];

    for my $h (keys %$doc) {
        for (@{$doc->{$h}}) {
            s/\s+//g;
        }
        @{$doc->{$h}} = grep { $_ ne '' } @{$doc->{$h}};
        if (@{$doc->{$h}} == 0) {
            delete $doc->{$h};
        }
    }

    my @headers = keys %$doc;
    my $doc2 = {};
    (cartesian { [ sort ($_[0], $_[1]) ] } (\@headers, \@headers))->each(
        sub {
            my $fields = $_;
            return if $fields->[0] eq $fields->[1];
            return if index($fields->[0], "subject") >= 0 && index($fields->[1], "subject") >= 0;
            return unless ( @{$doc->{$fields->[0]}} && @{$doc->{$fields->[1]}} );
            my $ha = $fields->[0] . "," . $fields->[1];
            return if $doc2->{$ha};
            $doc2->{$ha} //= [ (cartesian { $_[0] . "," . $_[1] } ($doc->{$fields->[0]}, $doc->{$fields->[1]}))->all ];
        }
    );

    delete $doc2->{'!date,to'};

    if ($doc->{subject_shingle}) {
        $doc2->{subject_shingle} = $doc->{subject_shingle};
    }

    return $doc2;
}

1;
