package Mailsheep::App::Command::minefp;
use v5.12;
use Mailsheep::App -command;

use Moo; with('Mailsheep::Role::Cmd');

use Tree::FP;
use YAML;

use Mailsheep::Analyzer;

sub opt_spec {
    return (
        [ "folder=s",  "The folder name." ]
    );
}

sub tokenize {
    my ($self, $message) = @_;
    my @t;

    push @t, map {
        "subject:$_"
    } Mailsheep::Analyzer::standard(($message->head->study("subject")  // ""));
    
    return \@t;
    # my $doc = {
    #     'reply-to' => [($message->head->study("reply-to") // "").""],
    #     'list-id'  => [(($message->head->study("List-Id") // "")."")],

    #     'delivered-to' => [($message->head->study("delivered-to") // "").""],
    #     'from.name' => [ (map { ($_->name||"") } $message->from) ],
    #     fromish => [
    #         uniq grep { $_ } map { $_ ? split(/[ \(\)\[\]]/, $_) : () } (
    #             (map { ($_->address ||"",  $_->name||"" ) } $message->from),
    #             (map { $_->address ||"" } $message->sender),
    #         )
    #     ],

    #     'to.name'    => [ map { $_->name    ||"" } $message->to ],
    #     'to.address' => [ map { $_->address ||"" } $message->to ],

    #     subject    => ,
    # }
}

sub execute {
    my ($self, $opt) = @_;

    my %tf;
    my @doc;

    my $folder_name = $opt->{folder};
    my $mgr = $self->mail_box_manager;
    my $folder = $mgr->open("=${folder_name}", access => "r") or die "$folder_name does not exists\n";
    my $count_message = $folder->messages;
    for my $i (0..$count_message-1) {
        my $message = $folder->message($i);
        my $t = $self->tokenize($message);
        push @doc, $t;
        $tf{$_}++ for @$t;
    }

    my $fptree = Tree::FP->new( sort { $tf{$b} <=> $tf{$a} } keys %tf );

    for my $t (@doc) {
        $fptree->insert_tree(@$t);
    }
    
    
    print YAML::Dump(\%tf);
    
}

1;
