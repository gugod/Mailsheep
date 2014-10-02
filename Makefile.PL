use inc::Module::Install;
name 'Mailsheep';
version '1.0';
all_from 'lib/Mailsheep/App.pm';

install_script "bin/mailsheep-train";
install_script "bin/mailsheep-categorize";
install_script "bin/mailsheep-purge-old";

license 'cc0';
cpanfile;
WriteAll;
