package Mailsheep::Cmd::Stats;
use v5.12;
use Moo; with('Mailsheep::Role::Cmd');

has fields => (
    is => "ro",
    default => "From"
);

sub execute {
    my $self = shift;

    my $fields = [ split ",", $self->fields ];
    my $aggregation = $self->aggregate($fields);

    printf("%10s %-60s\n", "Messages", join(",",@$fields));
    printf(("="x70)."\n");
    for (@$aggregation) {
        printf("%10d %-60s\n", $_->[1], $_->[0]);
    }
}

sub aggregate {
    my ($self, $fields) = @_;
    my %aggregation;

    my $mgr = $self->mail_box_manager;
    my %folder;
    for my $folder (@{$self->config->{folders}}) {
        my $x = $folder->{name};
        $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
    }

    for (values %folder) {
        for my $m ($_->messages) {
            my @term;
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

