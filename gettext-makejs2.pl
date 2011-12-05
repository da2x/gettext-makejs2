#!/usr/bin/perl -w

use strict;
use HTML::Entities;

die("One or more gettext .po[t] files is required as only argument.\n") unless ($#ARGV + 1);
my @source_files = @ARGV;
my $object_name = '18n-strings';
if ($ENV{GETTEXT_MAKEJS2_NAME})
{
  $object_name = $ENV{GETTEXT_MAKEJS2_NAME};
}
my $output_file_suffix = '.i18n';
if ($ENV{GETTEXT_MAKEJS2_SUFFIX})
{
  if ($ENV{GETTEXT_MAKEJS2_SUFFIX} eq "OFF")
  {
    undef $output_file_suffix;
  }
  else
  {
    $output_file_suffix = $ENV{GETTEXT_MAKEJS2_SUFFIX};
  }
}

sub detectScriptFilesFromSourceFiles
{
  my @translated_scripts;
  foreach my $po_source_file (@source_files)
  {
    open(i18nin, "<$po_source_file") or die $!;
    while (<i18nin>)
    {
      next unless /(?<=^\#\:\s).*?\.js(?=\:)/;
      my $script_path = $&;
      push (@translated_scripts, $script_path);
    }
   close i18nin;
  }
  use List::MoreUtils qw(uniq);
  return uniq @translated_scripts;
}

sub makeDirectoryHierarchyFromFilePath
{
  my $file_path = $_[0];
  use File::Basename qw(dirname);
  my $directory_path = dirname($file_path);
  use File::Path qw(make_path);
  make_path("$directory_path");
}

foreach my $script_file (detectScriptFilesFromSourceFiles)
{
  foreach my $po_source_file (@source_files)
  {
    $po_source_file =~ /^([a-z]{2,})/;
    my $language = $1;
    my $translated_keypairs = '';
    open(i18nin, "<$po_source_file") or die $!;
    while (<i18nin>)
    {
      next unless /(?<=^\#\:\s)\Q$script_file\E/;
      my $next;
      do
      {
        $next = <i18nin>;
      } while $next =~ /(?<=^\#\:\s)\Q$script_file\E/;
      my $fuzzy = 0;
      $fuzzy = 1 if $next =~ /fuzzy/;
      $next = <i18nin> if $next =~ /^#,/;
      my $msgid = '';
      if ($next =~ /^msgid ""\s+$/)
      {
        my $line;
        while (($line = <i18nin>) !~ /msgstr/)
        {
          chomp($line);
          $msgid .= substr($line, 1, -1);
        }
        $next = $line;
      }
      else
      {
        ($msgid) = $next =~ /^msgid "(.*)"/;
        $next = <i18nin>;
      }
      my $msgstr = '';
      if (!$fuzzy && !$next =~ /^\s\z$/)
      {
        if ($next =~ /^msgstr ""\s+$/)
        {
          while ((my $line = <i18nin>) !~ /^\s+(?!\z)$/)
          {
            chomp($line);
            $msgstr .= substr($line, 1, -1);
          }
        }
        else
        {
          ($msgstr) = $next =~ /^msgstr "(.*)"/;
        }
      }
      _decode_entities($msgstr, { nbsp => "\xc2\xa0", ocirc => "\xc3\xb4" });
      $translated_keypairs .= "  \"$msgid\":\"$msgstr\",\n";
    }
    close i18nin;
    $translated_keypairs = substr($translated_keypairs, 0, -2);
    my $script_base_file_name = substr $script_file, 0, -3; # always assumes ".js"
    my $output_file_extensions;
    if ($output_file_suffix)
    {
      $output_file_extensions = "$output_file_suffix.js";
    }
    else
    {
      $output_file_extensions = ".js";
    }
    my $output_file_path = "$language/$script_base_file_name$output_file_extensions";
    makeDirectoryHierarchyFromFilePath($output_file_path);
    open (i18nout, ">$output_file_path") or die;
    print i18nout "var $object_name = {\n";
    print i18nout $translated_keypairs;
    print i18nout "\n}\n";
    close i18nout;
    print "Wrote $output_file_path\n";
  }
}