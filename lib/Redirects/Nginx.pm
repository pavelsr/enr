package Redirects::Nginx;
use Config::Neat v1.302;
use List::MoreUtils qw(firstidx);
use Tie::File;
use Log::Any qw($log);
use feature 'say';

use Data::Dumper;
# This module finds all redirects in Nginx config


$SIG{'__WARN__'} = sub { warn $_[0] unless (caller eq "Config::Neat"); };
my @file;  # in-memory storage for nginx config file
my $neat = Config::Neat->new;


=head2 new

    my $ncfg = Redirects::Nginx->new();
    my $ncfg = Redirects::Nginx->new($nginx_cnf_filename);

=cut

sub new {
    my ($class, $filename) = @_;
    return bless {
        'filename' => $filename,
        'diff' => [],
        'redirects' => []
    }, $class;
}

# Just parse and validate

sub _parse_nginx_cnf {
    my $self = shift;
    my $data = $neat->parse_file($self->{'filename'});
    warn "Empty server: " unless $data->{'server'};
    tie @file, 'Tie::File', $self->{'filename'} or die 'Can not init Tie::File';

    # $data->{server} could be
    # 1) undef if no one server directive created
    # 2) hash if only one server directive created
    # 3) Config::Neat::Array if more than one directive created
    my @parsed_config;
    if ( ref($data->{'server'}) eq 'Config::Neat::Array') {
        @parsed_config = @{$data->{'server'}};
    }
    elsif ( ref($data->{server}) eq 'HASH') {
        @parsed_config = ( $data->{'server'} );
    }
    else {
        die 'Unknown data->server type: '.Dumper( ref($data->{server}) );
    }

    # Bit of validation
    my @result;
    my $ne_pattern = '^(http|https):\/\/\$host\$request_uri';
    for my $hash (@parsed_config) {
        push @result, $hash if (  exists $hash->{server_name} && exists $hash->{return} && ( $hash->{return}[0] == '301' ) && ( $hash->{return}[1] !~ qr/$ne_pattern/ ) );
    }
    return \@result;
}

=head2 parse_redirects

Parse + find string numbers and convert all Config::Neat::Array objects to whitespace separated string

Push result (array) to $self->{redirects} key

=cut

sub parse_redirects {
    my $self = shift;
    for my $hash (@{$self->_parse_nginx_cnf}) {
        # search string number
        $hash->{server_name} = $hash->{server_name}->as_string;
        $hash->{return} = $hash->{return}->as_string;
        my $pattern = '^\s*server_name\s*'.$hash->{server_name}; # Config::Neat::Array::as_string
        $hash->{str_from} = firstidx { $_ =~ qr/$pattern/ } @file;
        $hash->{str_to} = $hash->{str_from} + 2;
        $hash->{str_from}--; # server{} directive is prev string
        push @result, $hash;
    }
    $self->{redirects} = \@result;
}

=head2 add

Add redirect directive to $self->{diff}

    $ncfg->add({ 'i.example.com' => 'https://example.com/i' });

=cut

sub add {
    my ($self, $hash) = @_;
    push @{$self->{diff}}, { 'type' => 'add', 'dir_str' => $self->create_redirect_str($hash) };
}


=head2 modify

# Search and modify return value in $self->{redirects} by server_name, push result to $self->{diff}

      $ncfg->modify({ 'i.example.com' => 'https://example.com/i' });

=cut

sub modify {
    my ($self, $hash) = @_;
    my $server_name = (keys %$hash)[0];
    my $new_return = (values %$hash)[0];
    my $indextomodify = firstidx { $_->{server_name} eq $server_name.';'  } @{$self->{redirects}};
    if ($indextomodify != -1) {
        push @{$self->{diff}}, {
            'type' => 'modify',
            'dir_str' => $self->create_redirect_str({ $server_name => $new_return }),
            'str_from' => $self->{redirects}[$indextomodify]{str_from},
            'str_to' => $self->{redirects}[$indextomodify]{str_to}
        };
    }
    else {
        $log->info("Index not found, nginx config would not be affected");
    }
}


=head2 add

# Remove server from $self->{redirects} by its name, push result to $self->{diff}

      $ncfg->remove( 'i.example.com' );

=cut

sub remove {
    my ($self, $server_name) = @_;
    my $indextoremove = firstidx { $_->{server_name} eq $server_name.';' } @{$self->{redirects}};
    if ($indextoremove != -1) {
        push @{$self->{diff}}, {
            'type' => 'remove',
            'str_from' => $self->{redirects}[$indextoremove]{str_from},
            'str_to' => $self->{redirects}[$indextoremove]{str_to}
        };
    }
    else {
        $log->info("Index not found, nginx config would not be affected");
    }
}

=head2 create_redirect_str

# Creates server redirect str from hash

      $ncfg->create_redirect_str( 'i.example.com' => 'https://example.com/i' );

=cut

sub create_redirect_str {
    my ($self, $kv_pair) = @_;
    return 'server {'."\n".' server_name '.(keys %$kv_pair)[0].';'."\n".' return 301 '.(values %$kv_pair)[0].'$request_uri;'."\n".'}'."\n";
}


=head2 sync

Sync $self->{diff} with nginx config

    $ncfg->sync;

=cut

sub sync {
    my $self = shift;
    for my $d (@{$self->{diff}}) {
        if ($d->{type} eq 'add') {
            push @file, $d->{dir_str};
        } elsif ($d->{type} eq 'remove') {
            my $length = $d->{str_to} - $d->{str_from} + 1;
            splice @file, $d->{str_from}, $length;
        } elsif ($d->{type} eq 'modify') {
            my $length = $d->{str_to} - $d->{str_from} + 1; # +1 cause of \n
            splice @file, $d->{str_from}, $length, $d->{dir_str};
        } else {
            warn "unknown diff type";
        }
    }
    $self->parse_redirects;
    delete $self->{diff};
}

=head2 has_diff

Check is there any updates in diff (useful for optimization)

=cut

sub has_diff {
    my $self = shift;
    return ( scalar @{$self->{diff}} > 0) ? 1 : 0;
}

=head2 print

Print all nginx redirects in a human readible way (useful for debug)

=cut


sub print {
    my $self = shift;
    say "REDIRECTS FROM NGINX: ";
    say " ======================== ";
    my %r = %{$self->as_hash};
    while( my($k, $v) = each %r ) {
        say $k.' : '.$v;
    }
}

=head2 sync

Translate all redirects to hash

Read data directly from nginx config, specified in $self->{filename}, not from $self->{redirects}

=cut


sub as_hash {
    my $self = shift;
    my $res = {};
    for my $r (@{$self->_parse_nginx_cnf}) {
        my $key = $r->{server_name}->as_string;
        my $val = (split( '\$', $r->{return}->[1] ))[0];
        chop($key);
        $res->{$key} = $val;
    }
    return $res;
}

1;
