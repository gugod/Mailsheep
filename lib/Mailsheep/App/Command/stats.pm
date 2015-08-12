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
        [ "fields=s",  "Comma-separated list of fields", { default => "From" } ],
        [ "where=s",  "Constraint. Ex: To=me\@example.com" ]
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $fields = [ split ",", $opt->{fields} ];
    my $aggregation = $self->aggregate($fields, $opt->{where});

    printf("%10s %-60s\n", "Messages", join(",",@$fields));
    printf(("="x70)."\n");
    for (@$aggregation) {
        printf("%10d %-60s\n", $_->[1], $_->[0]);
    }
}

sub aggregate {
    my ($self, $fields, $constraint) = @_;
    my %aggregation;

    my $mgr = $self->mail_box_manager;
    my %folder;
    for my $folder (@{$self->config->{folders}}) {
        my $x = $folder->{name};
        $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
    }

    my ($constraint_field, $constraint_value) = split(/=/, $constraint) if $constraint;

    for (values %folder) {
        for my $m ($_->messages) {
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
    return [ map { [ $_, $aggregation{$_} ] } sort { $aggregation{$b} <=> $aggregation{$a} } keys %aggregation ];
}

1;

