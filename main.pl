#!/usr/bin/env perl


# change to bin directory
our $BINDIR;
use File::Basename;
BEGIN{
    my $BINDIR = dirname(__FILE__);
    chdir "$BINDIR";
}


use strict;
use warnings FATAL => 'all';

use lib 'lib','app';
# use File::Copy;
# use File::Slurp qw(write_file);
# use YAML::Tiny;
# use Data::Dumper;

use Docker::Menu::App;

my $app = new Docker::Menu::App();
$app->init();
$app->run();