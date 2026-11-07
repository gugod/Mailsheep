package Mailsheep::OllamaBasedCategorizer;
use v5.42;
use Moo;
use WebService::Ollama;
use Ref::Util qw(is_plain_arrayref);

has categories => (
    is => "ro",
    required => 1,
    isa => sub {
        -d $_[0] && is_plain_arrayref($_[0])
    }
);

sub train ( $self, $category, $documents ) {
    die "No training is required"
}

sub classify ( $self, $doc ) {
    state $JSON = JSON->new->utf8->canonical;

    my $ollama = WebService::Ollama->new(
        base_url => 'http://localhost:11434',
        model => 'gemma4:e4b'
    );

    my $doc_as_text = $JSON->encode($doc);

    my $categories_with_descriptions = join "\n", map {
        $_->{name} . ": " . $_->{description}
    } (
        @{$self->categories},
        {name => "NoneOfTheAbove", description => "When none of the above matches"}
    );

    my $date = localtime();
    my $response = $ollama->chat(
        messages => [
            +{
                "role" => "system",
                "content" => "You are a deterministic email classification model. Analyze the email text and classify it strictly according to the provided schema. It is $date now. Here is a list of categories with their descriptions. $categories_with_descriptions",
            },
            {
                "role" => "user",
                "content" => $doc_as_text,
            }
        ],
        "format" => {
            "type" => "object",
            "properties" => {
                "category" => {
                    "type" => "string",
                    "enum" => [
                        "ML",
                        "ML-Perl",
                        "News",
                        "Promotion",
                        "Junk",
                        "Spam",
                        "NoneOfTheAbove"
                    ]
                }
            },
            "required" => ["category"]
        },
        "options" => {
            "temperature" => 0.0
        },
        "stream" => 0,
    );

    my $res;

    try {
        $res = $JSON->decode($response->message->{content});
    } catch ($err) {
        $res = +{};
    };

    my $category = do {
        if ($res->{category} eq "NoneOfTheAbove") {
            undef;
        } else {
            $res->{category}
        }
    };

    return {
        category => $category
    };
}

no Moo;
1;
