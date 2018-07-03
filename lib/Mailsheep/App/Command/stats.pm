package Mailsheep::App::Command::stats;
# ABSTRACT: do some basic statistic aggregations
use v5.14;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
);

sub opt_spec {
    return (
        [ "folder=s",  "Comma-separated list of folders", { default => "INBOX" } ],
        [ "fields=s",  "Comma-separated list of fields", { default => "From" } ],
        [ "where=s",  "Constraint. Ex: To=me\@example.com" ]
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $fields = [ split ",", $opt->{fields} ];
    my $aggregation = $self->aggregate($opt->{folder}, $fields, $opt->{where});
    my $message_count = $aggregation->{message_count};
    printf("%10s %-60s\n", "Messages", join(",", @$fields));
    printf(("="x70)."\n");
    for (@{$aggregation->{frequency}}) {
        printf("%4.2f %10d %-60s\n", $_->[1]/$message_count, $_->[1], $_->[0]);
    }
}

sub aggregate {
    my ($self, $folder, $fields, $constraint) = @_;
    my %aggregation;

    my $mgr = $self->mail_box_manager;
    my %folder;
    $folder{$folder} = $mgr->open("=${folder}",  access => "r") or die "The mail box \"=$folder\" cannot be opened.\n";

    my ($constraint_field, $constraint_value) = split(/=/, $constraint) if $constraint;

    my $message_count = 0;
    for (values %folder) {
        for my $m ($_->messages) {
            $message_count++;
            my @term;
            if ($constraint) {
                my @v = $constraint_field eq 'From' ? (map{ $_->address} $m->from) : ($m->head->study($constraint_value));
                next unless grep { $_ eq $constraint_value } @v;
            }
            for my $f (@$fields) {
                push @term, ($f eq 'From' ? join(",", map{ $_->address} $m->from) : $m->head->study($f)) // "";
            }
            my $term = join(",", grep { $_ } @term);
            for my $from (map({ $_->address } $m->from)) {
                $aggregation{$term}++;
            }
        }
    }
    return {
        message_count => $message_count,
        frequency => [ map { [ $_, $aggregation{$_} ] } sort { $aggregation{$b} <=> $aggregation{$a} } keys %aggregation ]
    }
}

no Moo;
1;

