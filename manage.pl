#!/usr/bin/perl

use Linux::Inotify2;
use YAML::Syck;
use Hash::Diff qw( diff );
use Cwd;
use lib 'lib';
use Redirects::Nginx;
use AnyEvent;

use feature 'say';

use Data::Dumper;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Any::Adapter::Log4perl;
Log::Any::Adapter->set('Log4perl');



my $dir = getcwd;
my $nginx_cnf_filename = fef (
    $ENV{'ENR_NGINX_CFG_PATH'} ,    # for docker container customization, maybe it will needed some day
    $dir."/nginx.conf" ,            # main volume mount
    $dir."/examples/nginx.conf"     # for local testing without docker
);

my $yaml_cnf_filename = fef (
    $ENV{'ENR_YAML_CFG_PATH'} ,     # for docker container customization, maybe it will needed some day
    $dir."/config.yaml" ,           # main volume mount
    $dir.'/examples/config.yaml'    # for local testing without docker
);

my $opt = $ARGV[0];

if ($opt eq '-n') { # For debug
    my $ncfg = Redirects::Nginx->new($nginx_cnf_filename);
    $ncfg->parse_redirects;
    $ncfg->print;
    say "\nREDIRECTS FROM CONFIG: ";
    say " ======================== ";
    print `cat $yaml_cnf_filename`;
}
elsif ($opt eq '-f') {
    my $cv = AnyEvent->condvar;
    my $interval = $ENV{'ENR_INTERVAL'} || 60;
    my $time_watcher = AnyEvent->timer ( interval => $interval, cb => sub { sync_cycle() } );

    if ($ENV{'ENR_DISABLE_INOTIFY'}  != 1) {
        my $inotify = new Linux::Inotify2 or die "Unable to create new inotify object: $!" ;
        monitor($inotify); # setup file watcher and inotify actions
        my $inotify_watcher = AnyEvent->io (
           fh => $inotify->fileno, poll => 'r', cb => sub {
               $log->info("Inotify event was received");
               $inotify->poll;
           }
        );
    }

    $log->info("Monitoring service started");
    $log->info("Watching: redirects config: $yaml_cnf_filename, nginx config: $nginx_cnf_filename");
    $cv->recv;
}
elsif ($opt eq '-s') {
    # Just add only non-existing lines
    # If you just want to use only cron sync
    sync_cycle();
}
else {
    show_help();
}


=head2 sync_cycle()

This function (just) adds all servers from config.yaml to nginx config

It doesn't delete nginx redirects that are not in config.yaml

=cut


sub sync_cycle {
    $log->info("Start syncing....");
    my $ncfg = Redirects::Nginx->new($nginx_cnf_filename);
    my $redirects_from_nginx = $ncfg->as_hash;
    my $redirects_from_cnf = load_yaml($yaml_cnf_filename);
    foreach my $key (keys %$redirects_from_cnf) {
        if (!defined $redirects_from_nginx->{$key}) {
            $ncfg->add({ $key => $redirects_from_cnf->{$key} });
            $log->info("Server ".$key." was added");
        }
    }
    if ($ncfg->has_diff) {
        $ncfg->sync;
        reload_nginx();
        $log->info("Sync finished");
    }
    else {
        $log->info("Sync finished. No changes found");
    }

}


=head2 monitor()

# Monitors only diff between old and new configs and sync this diff with nginx config

Based on linux inotify. Will work if linux core version >= 2.6.13

=cut


sub monitor {
    my $inotify = shift;
    my $main_cnf_1 = load_yaml($yaml_cnf_filename);
    $inotify->watch ($yaml_cnf_filename, IN_CLOSE_WRITE, sub {
       my $ncfg = Redirects::Nginx->new($nginx_cnf_filename);
       $ncfg->parse_redirects;
       my $main_cnf_2 = load_yaml($yaml_cnf_filename);
       my $diff = diff( $main_cnf_2, $main_cnf_1 ); # leave
       my @diff_keys;
       push @diff_keys, keys %$diff;
       for my $key (@diff_keys) {
           if (!defined $main_cnf_2->{$key}) {
               $log->info("Server ".$key." was removed");
               $ncfg->remove($key);
           } elsif(!defined $main_cnf_1->{$key}) {
               $log->info("Server ".$key." was added");
               $ncfg->add({ $key => $main_cnf_2->{$key} });
           } elsif($main_cnf_1->{$key} ne $main_cnf_2->{$key}) {
               $log->info("Server ".$key." was changed");
               $ncfg->modify({ $key => $main_cnf_2->{$key} });
               warn "Chnaged!";
           } else {
               $log->info("Some unknown change");
           }
       };
       reload_nginx();
       $ncfg->sync;
       $main_cnf_1 = load_yaml($yaml_cnf_filename);
    });

}

=head2 reload_nginx()

Reload nginx config

=cut

sub reload_nginx {
    my $cmd = $ENV{'ENR_NGINX_RELOAD_CMD'} || 'docker kill -s HUP nginx';
    my $res = `$cmd`;
    $log->info($cmd);
    if ($res =~ qr/nginx/) {
        $log->info("nginx was successfully reloaded");
    } else {
        $log->info("Some problem occured when reloading nginx: ".$res);
    }
}


=head2 load_yaml()

Wrapper under YAML::Syck::LoadFile(). Return undef instead of die if file is empty or not exists

=cut

sub load_yaml {
    my $filename = shift;
    my $cnf;
    eval {
        $cnf = LoadFile($yaml_cnf_filename);
    };
    $log->info($filename.' is empty or not exists') if $@;
    return $cnf;
}

=head2 load_yaml()

fef = first_existing_file

returns filename of first existing file

=cut

sub fef {
  my @files = @_;
  for my $filename (@files) {
    if (-e $filename) {
      return $filename;
    }
  }
  return undef;
}

=head2 show_help()

Showing all available options (for now help isn't generated automatically)

=cut

sub show_help {
    print("
    Available options:\n
    -f - start foreground process\n
    -n - print all nginx redirects\n
    -s - sync changes (useful for cronjobs)\n
    ");
}
