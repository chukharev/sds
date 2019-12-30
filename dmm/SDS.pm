#!/usr/bin/perl -w
use strict;
use utf8;

# SDS Framework for Applied Linguisitcs
# Dialog Management Module (for perl)
# License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
# To the extent possible under law, Evgeny Chukharev-Hudilainen has waived all copyright and related or neighboring rights to this software.
# This work is published from the United States of America.

package SDS;

use Exporter 'import';
use vars qw(@EXPORT);
use IO::Socket::INET;

@EXPORT = qw(
  &sds_init &hear &say &last_said &before_say &has_spoken
);

my ($socket, $last_said, $before_say);

$| = 1;

my $id;
my $spoken_flag=0;

sub sds_init {
  my $voice = shift;
  if (@ARGV) {
    $id = $ARGV[0];
    $socket = new IO::Socket::INET (
      PeerHost => '127.0.0.1',
      PeerPort => '9999',
      Proto => 'tcp',
    );
    if (!$socket) {
      die("cannot create socket $!\n");
    }
    my @voices = qw(Amy Brian Emma Joanna Joey Kendra Kimberly Matthew Salli);
    $voice ||= $voices[int rand @voices];

    sleep 1;
    $socket->send(qq!{"id": "$id", "voice": "$voice"}\n!);
    sleep 1;
  }
}

sub hear {
  $spoken_flag = 0;
  if ($socket) {
    my $all_data = "";
    my $data;
    my $cnt;
    while (1) {
      $data = "";
      $socket->recv($data, 1);
      if (!length $data) {
        exit if $cnt++ > 10;
        sleep 1;
        next;
      }
      last if ($data eq "\n");
      $all_data .= $data;
    }
    if ($id) {
      open FH, ">> $id.log";
      print FH "$all_data\n";
      close FH;
    }

    if ($all_data eq '*BYE') {
      print "BYE received. Exiting\n";
      exit;
    }
    print("USER: $all_data\n");
    return $all_data;
  }
  print "USER: ";
  my $d = <>;
  chomp $d;
  return $d;
}

sub last_said {
  return $last_said
}

sub say {
  my $what = shift;
  $spoken_flag = 1;
  if (ref $before_say eq 'CODE') {
    local $_ = $what;
    $before_say->();
    $what = $_;
  }
  $last_said = $what;
  print("COMP: $what\n");
  if ($id) {
    open FH, ">> $id.log";
    print FH "$what\n";
    close FH;
  }
  if ($socket) {
    $socket->send("$what");
  }
}

sub before_say {
  $before_say = shift;
}

sub has_spoken {
  return $spoken_flag;
}

1;