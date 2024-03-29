package Mailsheep::FeatureAggregator;
use v5.36;
use Moo;
use Sereal::Encoder;

has store => (
    is       => "ro",
    required => 1,
    isa      => sub { -d $_[0] }
);

=begin

The "aggs" attribute stores all the non-zero frequency of the
attribute values over each category.

{
    category => {
        "from=john@example.com": {
            "News": 3, "Junk": 1
        }
    }
}

=cut

has aggs => (
    is      => "ro",
    default => sub {
        return { category => {} };
    }
);

sub feed ( $self, $category, $features ) {
    my $agg = $self->aggs->{category};
    for my $f (@$features) {
        $agg->{$f}{$category}++;
    }

    return $self;
}

sub save ($self) {
    my $sereal = Sereal::Encoder->new;
    open my $fh, ">",
      File::Spec->catdir( $self->store, "feature_aggregation.sereal" );
    print $fh $sereal->encode( $self->aggs );
    close($fh);

    return $self;
}

no Moo;
1;
