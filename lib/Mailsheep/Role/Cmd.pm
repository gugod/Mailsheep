package Mailsheep::Role::Cmd;
use Moo::Role;
has xdg => ( is => "lazy" );
has config => (is => "lazy");
has mail_box_manager => ( is => "lazy" );

use File::XDG;
use File::Spec::Functions qw(catfile);
use Mail::Box::Manager;
use JSON;

sub _build_xdg {
    my $self = $_[0];
    return File::XDG->new( name => "mailsheep" );
}

sub _build_mail_box_manager {
    my $self = shift;
    return Mail::Box::Manager->new( folderdir => $self->config->{maildir} ),
}

sub _build_config {
    my $self = shift;
    my $config_dir = $self->xdg->config_home;
    my $config_file = catfile($config_dir, "config.json");
    unless (-f $config_file) {
        die "config file $config_file does not exist.";
    }

    open(my $fh, "<", $config_file) or die $!;
    local $/ = undef;
    my $config_text = <$fh>;
    close($fh);
    my $json = JSON->new;
    return $json->decode($config_text);
}

1;
