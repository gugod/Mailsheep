use v5.18;

package MessageOrganizer {
    use Moo;
    use Email::MIME;
    use Encode qw(decode_utf8 encode_utf8);
    use List::Util qw(max sum);
    use List::MoreUtils qw(uniq);
    use JSON;
    use Tokenize;
    my $json = JSON->new;

    has idx => (
        is => "ro",
        required => 1,
    );

    sub looks_like {
        my ($self, $doc) = @_;

        my $idx = $self->idx;

        my %guess;

        for my $field (keys %$doc) {
            next if $doc->{$field} eq '';

            my $category;
            my $v = Tokenize::filter_characters($doc->{$field});
            my @tokens = ($v, Tokenize::standard($v));

            my (%pc,%p);
            my $total_docs = sum(map { $_->{df} } values %$idx);
            for $category (keys %$idx) {
                for my $token (@tokens) {
                    $p{$token}{$category} = ($idx->{$category}{field}{$field}{token}{$token}{tf} ||0) / $idx->{$category}{field}{$field}{tf};
                }
                $pc{$category} = $idx->{$category}{df} / $total_docs;
            }

            my (%matched, %score);
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
            };
        }

        my @guess = sort { $b->{maxscore} <=> $a->{maxscore} } values %guess;
        return ($guess[0]{maxscore} == 0) ? undef : $guess[0]{category};
    }

};
1;
