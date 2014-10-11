package Mailsheep::Categorizer;
use v5.12;
use Moo;
use YAML;
use Sereal::Encoder;
use Sereal::Decoder;
use File::Basename qw(basename);
use Encode 'encode_utf8';
use List::Util qw(sum);
use List::MoreUtils qw(uniq);

has store => (
    is => "ro",
    required => 1,
    isa => sub { -d $_[0] }
);

has idx => (
    is => "lazy"
);

sub _build_idx {
    my $self = shift;
    my $idx = {};

    my $store = $self->store;
    my $sereal = Sereal::Decoder->new;
    for my $fn (<$store/*.sereal>) {
        my $box_name = basename($fn) =~ s/\.sereal$//r;
        next if lc($box_name) eq 'inbox';
        open my $fh, "<", $fn;
        local $/ = undef;
        $idx->{$box_name} = $sereal->decode(<$fh>);
    }
    return $idx;
}

sub train {
    my ($self, $category, $documents) = @_;

    my $idx = {};
    for my $document (@$documents) {
        $idx->{df}++;
        for my $field (keys %$document) {
            my $fidx = $idx->{field}{$field} ||= {};
            my @tokens = @{$document->{$field}};
            $fidx->{tf} += @tokens;
            $idx->{tf}  += @tokens;

            my %seen;
            for my $token (@tokens) {
                $fidx->{token}{$token}{tf}++;
                $seen{$token}++;
            }
            $fidx->{count_utoken} += keys %seen;
            for my $token (keys %seen) {
                $fidx->{token}{$token}{df}++;
            }
        }
    }

    my $sereal = Sereal::Encoder->new;
    open my $fh, ">", File::Spec->catdir($self->store, "${category}.sereal");
    print $fh $sereal->encode($idx);
    close($fh);

    open $fh, ">", File::Spec->catdir($self->store, "${category}.yml");
    print $fh encode_utf8(YAML::Dump($idx));
    close($fh);
}

sub classify {
    my ($self, $doc) = @_;

    my $idx = {%{$self->idx}};
    for (keys %$idx) {
        delete $idx->{$_} unless keys %{ $idx->{$_} };
    }
    my $total_docs = sum(map { $_->{df} } values %$idx);

    my %guess;
    for my $field (keys %$doc) {
        next if $doc->{$field} eq '';

        my $category;
        my @tokens = @{$doc->{$field}} or next;

        my (%pc,%p);
        for $category (keys %$idx) {
            for my $token (@tokens) {
                if ($idx->{$category}{field}{$field}{tf} > 0) {
                    $p{$token}{$category} = ($idx->{$category}{field}{$field}{token}{$token}{tf} ||0) / $idx->{$category}{field}{$field}{tf};
                } else {
                    $p{$token}{$category} = 0;
                }
            }
            $pc{$category} = $idx->{$category}{df} / $total_docs;
        }

        my %score;
        for $category (keys %$idx) {
            my $score = $pc{$category};
            for (@tokens) {
                $score *= $p{$_}{$category};
            }
            $score{$category} = $score;
        }

        my @c = sort { $score{$b} <=> $score{$a} } keys %score;

        $guess{$field} = {
            field => $field,
            maxscore => $score{$c[0]},
            fieldLength => 0+@tokens,
            category   => $c[0],
            confidence => $score{$c[0]} / (sum(values %score) ||1),
            categories => \@c,
            score => \%score,
            tokens => \@tokens,
            token_p => \%p,
            categories_p => \%pc,
        };
    }

    my @guess = sort { $b->{maxscore} <=> $a->{maxscore} } values %guess;

    if (@guess) {
        return {
            score => $guess[0]{maxscore},
            guess => \@guess,
            category => ($guess[0]{maxscore} == 0 ? undef : $guess[0]{category}),
        };
    } else {
        return {
            score => 0,
            guess => \@guess,
            category => undef,
        };
    }
}

1;
