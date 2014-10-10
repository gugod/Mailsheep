package Mailsheep::Cmd::Help;
use Moo; with('Mailsheep::Role::Cmd');
sub execute {
    say "I can't help you";
}
1;

