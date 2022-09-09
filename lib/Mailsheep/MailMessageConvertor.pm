package Mailsheep::MailMessageConvertor;
use v5.36;
use Moo::Role;
use List::Gen ':modify';
use List::MoreUtils 'uniq';
use JSON;

use Importer 'Mailsheep::Analyzer' => 'reduced_mail_subject';

sub true()  { $JSON::true }
sub false() { $JSON::false }

sub convert_mail_message_to_simple_document ( $self, $message ) {
    my $head = $message->head;
    my $body = $message->body;

    my $doc = {
        'reply-to' => ["" . ( $head->study("reply-to") // "" )],
        'list-id'  => ["" . ( $head->study("List-Id")  // "" )],
        'from'     => [map { $_->format } $message->from],
        'sender'   => [map { $_->format } $message->sender],
        'to'       => [map { $_->format } $message->to],
        'subject'  => ["" . ( $head->study("subject") // "" )],

        # 'body'     => [ "" . $message->body->decoded ],
        ':ABOUT' => [
            nrLines         => $body->nrLines,
            bodyIsMultipart => ( $body->isMultipart ? true : false ),
            bodyMimeType    => ( "" . $body->mimeType ),
        ]
    };

    for my $h ( keys %$doc ) {
        @{ $doc->{$h} } = grep { $_ ne '' } @{ $doc->{$h} };
        if ( @{ $doc->{$h} } == 0 ) {
            delete $doc->{$h};
        }
    }

    return $doc;
}

sub convert_mail_message_to_analyzed_document ( $self, $message ) {
    my $head = $message->head;
    my $body = $message->body;
    my $doc = {
        'reply-to' => [( $head->study("reply-to") // "" ) . ""],
        'list-id'  => [( $head->study("List-Id")  // "" ) . ""],

        fromish => [
            uniq(
                $head->get("From"),
                ( map { ( $_->name || "" ) . "_" . ( $_->address || "" ) } $message->from ),
                ( map { ( $_->name || "" ) . "_" . ( $_->address || "" ) } $message->sender ),
            )
        ],

        'body.about' => [ join("_", $body->charset // "", $body->mimeType->simplified // "", $body->nrLines // 0) ],

        'to'    => [map { ( $_->name || "" ) . "_" . ( $_->address || "" ) } $message->to],
        '!date' => [( !$head->get("Date") )],
    };

    $doc->{subject} =
        [reduced_mail_subject( $head->study("subject") )];

    for my $h ( keys %$doc ) {
        for ( @{ $doc->{$h} } ) {
            s/\s+//g;
        }
        @{ $doc->{$h} } = grep { $_ ne '' } @{ $doc->{$h} };
        if ( @{ $doc->{$h} } == 0 ) {
            delete $doc->{$h};
        }
    }

    my @headers = keys %$doc;
    my $doc2    = {};
    ( cartesian { [sort ( $_[0], $_[1] )] } ( \@headers, \@headers ) )->each(
        sub {
            my $fields = $_;
            return if $fields->[0] eq $fields->[1];
            return
                unless ( @{ $doc->{ $fields->[0] } }
                && @{ $doc->{ $fields->[1] } } );
            my $ha = $fields->[0] . "," . $fields->[1];
            return if $doc2->{$ha};
            $doc2->{$ha} //= [
                (
                    cartesian { $_[0] . "," . $_[1] }
                    ( $doc->{ $fields->[0] }, $doc->{ $fields->[1] } )
                )->all
            ];
        }
    );

    delete $doc2->{'!date,to'};

    return $doc2;
}

1;
