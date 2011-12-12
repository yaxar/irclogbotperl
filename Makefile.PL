#!/usr/bin/env perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'A logging script',
  VERSION => '2.45',
  AUTHOR       => 'Yaxar <yarxar dot murat at gmail dot com>',
  EXE_FILES    => ['log.pl'],
PREREQ_PM    => {'Mojolicious' => '2.0',
    'Mojolicious::Lite' => 0,
    'EV' => 0,
    'AnyEvent::IRC' => 0,
    'AnyEvent::IRC::Client' => 0,
    'DateTime' =>0,},
  test         => {TESTS => 't/*.t'}
);
