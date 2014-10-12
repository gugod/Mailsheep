package Mailsheep::Cmd::FolderStats;
use v5.12;
use Moo; with('Mailsheep::Role::Cmd');
sub execute {
    my $self = shift;

    my $mgr = $self->mail_box_manager;
    my %folder;
    for my $folder (@{$self->config->{folders}}) {
        my $x = $folder->{name};
        $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
    }

    my @msgcount;
    for (values %folder) {
        push @msgcount, ["$_", 0+ $_->messages];
    }
    @msgcount = sort { $b->[1] <=> $a->[1] } @msgcount;
    $mgr->closeAllFolders;

    printf("%-20s%10s\n","Folder", "Messages");
    printf(("="x30)."\n");
    for (@msgcount) {
        printf("%-20s%10d\n", $_->[0], $_->[1]);
    }
}
1;

