package Mailsheep::MailMessageIterator;
use v5.18;
use Moo::Role;

use Ref::Util qw(is_hashref is_coderef);

sub iterate_through_mails {
    my ($self, $opt, $cb) = @_;
    return unless is_hashref($opt);
    return unless is_coderef($cb);

    my $mgr = $self->mail_box_manager;
    my %folder;
    if ($opt->{folder}) {
        $folder{$opt->{folder}} = $mgr->open("=$opt->{folder}",  access => "r") or die "The mail box \"=$opt->{folder}\" cannot be opened.\n";
    } else {
        for my $folder (@{$self->config->{folders}}) {
            my $x = $folder->{name};
            $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
        }
    }

    for (values %folder) {
        for my $m ($_->messages) {
            $cb->($m);
        }
    }
    return;
}

1;
