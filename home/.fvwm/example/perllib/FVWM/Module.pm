# Copyright (c) 2003-2009 Mikhael Goikhman
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package FVWM::Module;

use 5.004;
use strict;
use IO::File;

BEGIN {
	use vars qw($prefix $datarootdir $datadir);
	$prefix = "/usr/local";
	$datarootdir = "${prefix}/share";
	$datadir = "${datarootdir}";
}

use lib "${datadir}/fvwm/perllib";
use vars qw($VERSION @ISA @EXPORT $AUTOLOAD);

use FVWM::Constants;
use FVWM::Event;

use Exporter;
@EXPORT = @FVWM::Constants::EXPORT;
@ISA = qw(Exporter);

# The major version part indicates major API changes
$VERSION = '2.0';

# Set the fvwm search directories (used for non fully qualified file names)
$General::FileSystem::SAVE_FILE_DIR = $General::FileSystem::SAVE_FILE_DIR ||
	__PACKAGE__->user_data_dir();
$General::FileSystem::LOAD_FILE_DIRS = $General::FileSystem::LOAD_FILE_DIRS ||
	[ __PACKAGE__->search_dirs() ];

sub internal_die ($$) {
	my $self = shift;
	my $msg = shift;
	$msg =~ s/([^\.!?])$/$1./;
	die $self->name . ": $msg Exiting.\n";
}

sub show_error ($$) {
	my $self = shift;
	my $msg = shift;
	print STDERR $self->name . ": $msg\n";
}

sub show_message ($$) {
	my $self = shift;
	my $msg = shift;
	print STDERR "[" . $self->name . "]: $msg\n";
}

sub show_debug ($$) {
	my $self = shift;
	my $msg = shift;
	print STDERR "[" . $self->name . "]: $msg\n";
}

sub debug ($$;$) {
	my $self = shift;
	my $msg = shift;
	my $level = shift;
	$level = 1 unless defined $level;
	my $debug_level = $self->{debug};
	$debug_level = $ENV{FVWM_MODULE_DEBUG} if exists $ENV{FVWM_MODULE_DEBUG};
	return if $debug_level < $level;
	$msg =~ s/\n$//s;
	$self->show_debug($msg);
}

sub is_event_extended ($$) {
	my $self = shift;
	my $type = shift;
	return $type & M_EXTENDED_MSG ? 1 : 0;
}

sub new ($@) {
	my $class = shift;
	my %params = @_;
	my $self = {};

	my $name = $0; $name =~ s|.*/||;
	$name = $params{'Name'} || $name;
	my $mask = $params{'Mask'};
	my $xmask = $params{'XMask'};
	my $sync_mask = $params{'SyncMask'};
	my $sync_xmask = $params{'SyncXMask'};

	# initialize module from argv
	my ($out_fd, $in_fd, $rc_file, $win_id, $context);
	if (@ARGV >= 5 && $ARGV[0] =~ /^\d+$/ && $ARGV[1] =~ /^\d+$/) {
		$self->{is_dummy} = 0;
		($out_fd, $in_fd, $rc_file, $win_id, $context) = splice(@ARGV, 0, 5);
	} else {
		warn "$name should be spawned by fvwm normally.\n";
		warn "Activating a dummy command line mode for 30 minutes (no events).\n";
		warn "----------------------------------------------------------------\n";
		open(DUMMYOUT, '| cat >/dev/null');
		open(DUMMYIN, 'sleep 1800 |');
		$self->{is_dummy} = 1;
		($out_fd, $in_fd) = (fileno(DUMMYOUT), fileno(DUMMYIN));
		($rc_file, $win_id, $context) = ("none", 0, 0);
	}

	if (@ARGV && $params{'EnableAlias'} && $ARGV[0] =~ /^\w[\w\d\.\/-]*/) {
		$name = shift @ARGV;
	}
	if (@ARGV && ref($params{'EnableOptions'}) eq 'HASH') {
		# save time by lazy loading Getopt::Long only if needed
		eval "use Getopt::Long;"; die "$name: $@" if $@;
		GetOptions(%{$params{'EnableOptions'}})
			or die "$name: Incorrect options given.\n";
	}
	my @argv = @ARGV;

	$self->{rc_file} = $rc_file;
	$self->{win_id} = hex $win_id;
	$self->{context} = $context;
	$self->{argv} = [@argv];

	# a module may need this
	autoflush STDOUT;
	autoflush STDERR;

	$self->{ostream} = new IO::File ">&$out_fd"
		or die "$name: Can't write to file descriptor (&$out_fd)\n";
	$self->{istream} = new IO::File "<&$in_fd"
		or die "$name: Can't read from file descriptor (&$in_fd)\n";
	$self->{ostream}->autoflush(1);
	$self->{istream}->autoflush(1);

	$self->{disconnected} = 0;
	$self->{debug} = $params{'Debug'} || 0;
	$self->{debug} = ${$self->{debug}} if ref($self->{debug}) eq 'SCALAR';
	$self->{last_packet} = [];
	$self->{handlers} = {};
	$self->{should_send_unlock} = 0;
	$self->{should_send_ready} = 1;
	$self->{add_mask} = 0;
	$self->{add_xmask} = 0;
	$self->{mask_was_set} = defined $mask;
	$self->{xmask_was_set} = defined $xmask;

	$self->{held_command_args} = [];
	$self->{synthetic_events} = [];
	$self->{used_tracker_classes} = {};
	$self->{trackers} = {};

	# bless here, so die above does not run DESTROY
	bless $self, $class;
	$self->name($name);
	$self->mask($mask || 0, $self->{mask_was_set});
	$self->xmask($xmask, $self->{xmask_was_set}) if $xmask;
	$self->sync_mask($sync_mask || 0);
	$self->sync_xmask($sync_xmask) if $sync_xmask;
	$self->reset_handlers;
	return $self;
}

sub disconnect ($) {
	my $self = shift;

	# do nonrecoverable things, but do them only once
	return if $self->{disconnected};

	$self->{disconnected} = 1;
	$self->invoke_handler(new FVWM::Event(ON_EXIT));

	if (defined $self->{ostream} && $self->{ostream}->opened) {
		# TODO: should wait until fvwm actually gets it
		$self->send("Nop", 0, 0);
		close $self->{ostream};
	}
	if (defined $self->{istream} && $self->{istream}->opened) {
		close $self->{istream};
	}
}

sub DESTROY ($) {
	my $self = shift;
	$self->disconnect;
}

sub is_dummy ($) {
	my $self = shift;
	return $self->{is_dummy};
}

sub name ($;$) {
	my $self = shift;
	my $name = shift;
	$self->{name} = $name if defined $name;
	return $self->{name};
}

sub mask ($;$$) {
	my $self = shift;
	my $mask = shift;
	my $explicit = shift;
	$explicit = 1 unless defined $explicit;

	if (defined $mask) {
		$self->internal_die("mask() can't get extended mask, use xmask()")
			if $self->is_event_extended($mask);
		my $old_mask = $self->{mask};
		$self->send_mask($mask, $self->{add_mask})
			unless defined $old_mask && $old_mask == $mask;
		$self->{mask} = $mask;
		$self->{mask_was_set} = $explicit;
		return $old_mask;
	}
	return $self->{mask} || 0;
}

sub xmask ($;$$) {
	my $self = shift;
	my $mask = shift;
	my $explicit = shift;
	$explicit = 1 unless defined $explicit;

	if (defined $mask) {
		$mask &= ~M_EXTENDED_MSG;
		my $old_mask = $self->{xmask};
		$self->send_mask($mask | M_EXTENDED_MSG, $self->{add_xmask})
			unless defined $old_mask && $old_mask == $mask;
		$self->{xmask} = $mask;
		$self->{xmask_was_set} = $explicit;
		return $old_mask;
	}
	return $self->{xmask} || 0;
}

sub is_in_mask ($$) {
	my $self = shift;
	my $type = shift;
	my $mask = ($type & M_EXTENDED_MSG) ? $self->{xmask} : $self->{mask};
	return $type & ($mask || 0);
}

sub sync_mask ($;$) {
	my $self = shift;
	my $mask = shift;
	if (defined $mask) {
		$self->internal_die("sync_mask() can't get extended mask, use sync_xmask()")
			if $self->is_event_extended($mask);
		my $old_mask = $self->{sync_mask};
		$self->send("SET_SYNC_MASK $mask")
			unless defined $old_mask && $old_mask == $mask;
		$self->{sync_mask} = $mask;
		return $old_mask;
	}
	return $self->{sync_mask} || 0;
}

sub sync_xmask ($;$) {
	my $self = shift;
	my $mask = shift;
	if (defined $mask) {
		$mask &= ~M_EXTENDED_MSG;
		my $old_mask = $self->{sync_xmask};
		$self->send("SET_SYNC_MASK " . ($mask | M_EXTENDED_MSG))
			unless defined $old_mask && $old_mask == $mask;
		$self->{sync_xmask} = $mask;
		return $old_mask;
	}
	return $self->{sync_xmask} || 0;
}

sub is_in_sync_mask ($$) {
	my $self = shift;
	my $type = shift;
	my $mask = ($type & M_EXTENDED_MSG) ? $self->{sync_xmask} : $self->{sync_mask};
	return $type & ($mask || 0);
}

# by default the version of a module is the fvwm version
sub version ($) {
	my $self = shift;
	return "2.6.5";
}

sub version_info ($) {
	my $self = shift;
	return "";
}

sub argv ($) {
	my $self = shift;
	return @{$self->{argv}};
}

sub reset_handlers ($) {
	my $self = shift;

	$self->{handlers}->{regular} = {};
	$self->{handlers}->{extended} = {};
	$self->{handlers}->{special} = {};
}

sub get_handler_category ($$) {
	my $self = shift;
	my $type = shift;
	return "special" if $type =~ /e/i;
	return "extended" if $self->is_event_extended($type);
	return "regular";
}

sub postpone_send ($@) {
	my $self = shift;
	push @{$self->{held_command_args}}, [ @_ ];
}

# params: text, [win_id], [continue=0/1]
sub send ($$;$$) {
	my $self = shift;
	my $text = shift;
	my $win_id = shift || 0;
	my $continue = shift;
	$continue = 1 unless defined $continue;

	$self->internal_die("send requires at least text param")
		unless defined $text;

	my @lines = split(/\n/s, $text);

	my $last_line = "";
	for my $line (@lines) {
		# support continuation lines
		$line = "$last_line$line" if $last_line ne "";
		if ($line =~ /^(.*)\\$/) {
			$last_line = $1;
			next;
		} else {
			$last_line = "";
		}
		next if $line =~ /^\s*$/;

		unless ($self->{ostream}->opened) {
			$self->debug("Closed send [$line]\n", 1);
			next;
		}
		$self->debug("sent [$line]" . (!$continue && " FINISH"), 2);
		my $len = length $line;
		local $SIG{PIPE} = sub {
			$self->debug("Failed send [$line]\n", 1);
		};
		$self->{ostream}->print(
			pack("l!l!a${len}l!", $win_id, $len, $line, $continue)
		);
	}
	return $self;
}

sub send_ready ($) {
	my $self = shift;
	$self->send(RESPONSE_READY) if $self->{should_send_ready};
	$self->{should_send_ready} = 0;
	return $self;
}

sub send_unlock ($) {
	my $self = shift;
	$self->send(RESPONSE_UNLOCK) if $self->{should_send_unlock};
	$self->{should_send_unlock} = 0;
	return $self;
}

sub send_mask ($$;$) {
	my $self = shift;
	my $mask = shift;
	my $add_mask = shift || 0;

	$self->send("SET_MASK " . ($mask | $add_mask));
}

sub request_reply ($$) {
	my $self = shift;
	my $text = shift;
	my $win_id = shift;

	$self->send("Send_Reply $text", $win_id);
}

sub terminate ($;$) {
	my $self = shift;
	my $continue = shift || 0;
	die "!quit" if !$continue;
	die "!next";
}

sub wait_packet ($) {
}

sub read_packet ($) {
	my $self = shift;

	goto RETURN_PACKET if @{$self->{synthetic_events}};

	$self->{last_packet} = [];

	my $header = "";
	my $packet = "";

	$self->wait_packet;

	# read a packet's header first, sizeof(int) * HEADER_SIZE bytes long
	my $got;
	# With perl-5.8.0+, $SIG{ALRM} causes sysread to exit with "Illegal seek",
	# so loop around sysread. I am not sure this is safe.
	do {
		$got = sysread($self->{istream}, $header, INTSIZE * HEADER_SIZE);
	} until (defined $got);

	if ($got != (INTSIZE * HEADER_SIZE)) {
		# module killed or other read error
		$self->debug($got ? "read packet error" : "connection closed", 3);
		return undef;
	}

	my ($magic, $type, $len, $timestamp) =
		unpack(sprintf("L!%d", HEADER_SIZE), $header);
	$self->internal_die("Bad magic number $magic in packet")
		unless $magic == START_FLAG;

	# $type should not be anything other than a 32-bit number
	# however, extended messages are padded with set bits on 64-bit systems
	$type &= 0xffffffff;

	# $len is number of words in packet, including header;
	# we need this as number of bytes.
	$len -= HEADER_SIZE;
	$len *= INTSIZE;

	if ($len > 0) {
		my $off = 0;
		while ($off < $len) {
			$got = sysread($self->{istream}, $packet, $len, $off);
			if (!defined $got) {
				$self->internal_die("sysread error: $!");
			}
			$off += $got;
		}
		$self->internal_die("Got packet len $off while expecting $len")
			if $off != $len;
	}

RETURN_PACKET:
	($type, $packet) = @{shift @{$self->{synthetic_events}}}
		if @{$self->{synthetic_events}};
	$self->{last_packet} = [$type, $packet];
	return ($type, $packet);
}

sub invoke_handler ($$) {
	my $self = shift;
	my $event = shift;
	my $type = $event->type;

	my $category = $self->get_handler_category($type);
	my @masks = sort { $a <=> $b } keys %{$self->{handlers}->{$category}};
	foreach my $mask (@masks) {
		if ($type eq $mask || $type & $mask) {
			foreach my $handler (@{$self->{handlers}->{$category}->{$mask}}) {
				last unless $event->propagation_allowed;
				next unless defined $handler;  # skip deleted ones

				eval { &$handler($self, $event); };

				if ($@) {
					return 0 if $@ =~ /^!quit/i;
					return 1 if $@ =~ /^!next/i;
					die $@;
				}
			}
		}
	}
	return 1;
}

sub process_packet ($;$$) {
	my $self = shift;
	my ($type, $packet) = @_;

	($type, $packet) = @{$self->{last_packet}} unless defined $packet;
	return undef unless defined $packet;

	my $event = eval { new FVWM::Event($type, $packet); };
	$self->internal_die($@ || "Internal error") unless defined $event;

	if ($self->{debug}) {
		my $msg = "got " . $event->name;
		$msg .= " [" . $event->arg_values->[-1] . "]"
			if @{$event->arg_types} && $event->arg_types->[-1] == FVWM::EventNames::string();
		$self->debug($msg, 2);
	}

	$self->{should_send_unlock} = 1 if $self->is_in_sync_mask($type);

	my $continue = $self->invoke_handler($event);

	$self->send_unlock if $self->{should_send_unlock};
	return $continue;
}

sub emulate_event ($$$) {
	my $self = shift;
	my ($type, $packet) = @_;

	if ($self->{is_in_event_loop}) {
		$self->invoke_handler(new FVWM::Event($type, $packet));
		return;
	}

	push @{$self->{synthetic_events}}, [$type, $packet];
}

sub event_loop_prepared ($@) {
	my $self = shift;
	my $tracking = shift() ? 1 : 0;

	if (!$self->{is_in_event_loop}) {
		$self->send_ready unless $tracking;
		$self->debug("entered event loop", 3 + $tracking);
		$self->{is_in_event_loop} = 1;
	}

	# update module masks to handle trackers if needed
	my $add_mask  = 0;
	my $add_xmask = 0;
	foreach (values %{$self->{trackers}}) {
		my ($mask, $xmask) = $_->masks;
		$add_mask  |= $mask;
		$add_xmask |= $xmask;
	}
	$self->send_mask($self->mask, $self->{add_mask} = $add_mask)
		if $add_mask != $self->{add_mask};
	$self->send_mask($self->xmask | M_EXTENDED_MSG, $self->{add_xmask} = $add_xmask)
		if $add_xmask != $self->{add_xmask};

	# execute postponed commands if any
	$self->send(@{shift @{$self->{held_command_args}}})
		while @{$self->{held_command_args}};

	# fire emulated events if any
	$self->process_packet(@{shift @{$self->{synthetic_events}}})
		while !$tracking && @{$self->{synthetic_events}};
}

sub event_loop_finished ($@) {
	my $self = shift;
	my $tracking = shift() ? 1 : 0;

	$self->debug("exited event loop", 3 + $tracking);

	unless ($tracking) {
		foreach my $tracker (values %{$self->{trackers}}) {
			$tracker->to_be_disconnected;
		}
		$self->disconnect;
	}

	$self->{is_in_event_loop} = 0;
}

sub event_loop ($@) {
	my $self = shift;

	while (1) {
		$self->event_loop_prepared(@_);

		# catch exceptions during read, for example from alarm() handler,
		# but don't catch errors (or die) in event handlers
		$self->process_packet(eval { $self->read_packet }) || last;
	}
	$self->event_loop_finished(@_);
}

sub track ($$;$@) {
	my $self = shift;
	my $params = ref($_[0]) eq 'HASH' ? shift() : {};
	my $tracker_type = shift;

	my $tracker_class = $tracker_type =~ /::/
		? $tracker_type : "FVWM::Tracker::$tracker_type";
	# load a tracker class if not yet
	unless (defined $self->{used_tracker_classes}->{$tracker_class}) {
		eval "use $tracker_class;"; die $@ if $@;
		$self->{used_tracker_classes}->{$tracker_class} = 1;
	}

	my $tracker = !$params->{NoReuse} && $self->{trackers}->{$tracker_type}
		|| $tracker_class->new($self, @_);
	if ($params->{NoReuse}) {
		$tracker_type .= "+" while exists $self->{trackers}->{$tracker_type};
	}
	$self->{trackers}->{$tracker_type} = $tracker;
	$tracker->start unless $params->{NoStart};
	return $tracker;
}

sub add_handler ($$$;$) {
	my $self = shift;
	my $type = shift;
	my $handler = shift;
	my $is_tracking = shift || 0;

	$self->internal_die("add_handler: no handler type") unless defined $type;
	$self->internal_die("add_handler: no handler code") unless ref($handler) eq 'CODE';

	my $category = $self->get_handler_category($type);
	$self->{handlers}->{$category}->{$type} = []
		unless exists $self->{handlers}->{$category}->{$type};
	push @{$self->{handlers}->{$category}->{$type}}, $handler;
	my $index = @{$self->{handlers}->{$category}->{$type}} - 1;

	unless ($is_tracking) {
		$self->mask($self->mask | $type, 0)
			if !$self->{mask_was_set} && $category eq "regular";
		$self->xmask($self->xmask | $type, 0)
			if !$self->{xmask_was_set} && $category eq "extended";
	}

	return [$type, $index];
}

sub delete_handler ($$) {
	my $self = shift;
	my $id = shift;

	return 0 unless ref($id) eq 'ARRAY' && @$id == 2;
	my ($type, $index) = @$id;
	my $category = $self->get_handler_category($type);
	return 0 unless defined $self->{handlers}->{$category}->{$type}->[$index];

	$self->{handlers}->{$category}->{$type}->[$index] = undef;
	return 1;
}

sub add_default_error_handler ($) {
	my $self = shift;

	$self->add_handler(M_ERROR, sub {
		my ($self, $type, @args) = @_;
		my $error = $args[3];
		print STDERR "[", $self->name, "]: got fvwm error: $error\n";
		#$self->terminate;
	});
}

sub user_data_dir ($) {
	return $ENV{FVWM_USERDIR} || (($ENV{HOME} || "") . "/.fvwm");
}

sub site_data_dir ($) {
	return "${datadir}/fvwm";
}

sub search_dirs ($) {
	my $this = shift;
	return ($this->user_data_dir, $this->site_data_dir);
}

# support old API, like addHandler, dispatch to add_handler
sub AUTOLOAD ($;@) {
	my $self = shift;
	my @params = @_; 

	my $autoload_method = $AUTOLOAD;
	my $method = $autoload_method;  

	# remove the package name
	$method =~ s/.*://g;

	$method =~ s/XMask/Xmask/;
	$method =~ s/([a-z])([A-Z])/${1}_\L$2/g;

	die "No method $method in $self as guessed from $autoload_method"
		unless $self->can($method);

	$self->$method(@params);
}

1;

__END__

=head1 NAME

FVWM::Module - the base class representing fvwm module

=head1 SYNOPSIS

    use lib `fvwm-perllib dir`;
    use FVWM::Module;

    my $module = new FVWM::Module;

    $module->send("Beep");

    # auto-raise all windows
    sub auto_raise { $_[0]->send("Raise", $_[1]->_win_id) };
    $module->add_handler(M_FOCUS_CHANGE, \&auto_raise);

    # terminate itself after 5 minutes
    my $scheduler = $module->track('Scheduler');
    $scheduler->schedule(5 * 60, sub { $module->terminate; });

    # print the current desk number ($page_tracker is auto updated)
    my $page_tracker = $module->track("PageInfo");
    $module->show_message("Desk: " . $page_tracker->data->{desk_n});

    $module->event_loop;

=head1 DESCRIPTION

An fvwm module is a separate program that communicates with the main I<fvwm>
process, receives a module configuration and events and sends commands back.
This class B<FVWM::Module> makes it easy to create fvwm modules in Perl.

If you are interested in all module protocol details that this class tries
to make invisible, visit the web page
I<http://fvwm.org/documentation/dev_modules.php>.
You will need an information about packet arguments anyway to be able to
write complex modules. This is however not obligatory for simple modules
that only send commands back when something happens.

A typical fvwm module has an initialization part including setting event
handlers using B<add_handler> methods and entering an event loop using
B<event_loop> method. Most of the work is done in the event handlers although
a module may define other execution ways, for example using C<$SIG{ALRM}>.

An fvwm module receives 3 values from I<fvwm>: I<rc_file> - the file this
module was called from or "none" if the module is called as a command from
another module or from a binding/function (this value is not really useful),
I<win_id> - the window context of this module if it is called from window
decoration bindings or window menu (the value is integer, 0 if there is no
window context), and finally I<context> that indicates the place this module
was called from, like menu or window title (see the fvwm documentation).
All these values may be accessed as properties of the module object,
like C<$module-E<gt>{win_id}>.

=head1 METHODS

The following methods are available:

B<new>,
B<version>,
B<version_info>,
B<argv>,
B<send>,
B<track>,
B<event_loop>,
B<send_ready>,
B<send_unlock>,
B<request_reply>,
B<postpone_send>,
B<terminate>,
B<reset_handlers>,
B<add_handler>,
B<delete_handler>,
B<add_default_error_handler>,
B<debug>,
B<show_error>,
B<show_message>,
B<show_debug>,
B<is_dummy>.

The following methods are called from other methods above, but may be useful
in other situations as well:

B<internal_die>,
B<name>,
B<mask>,
B<xmask>,
B<is_in_mask>,
B<sync_mask>,
B<sync_xmask>,
B<is_in_sync_mask>,
B<disconnect>,
B<get_handler_category>,
B<read_packet>,
B<invoke_handler>,
B<process_packet>,
B<emulate_event>.

These methods deal with a received packet (event):

B<is_event_extended>

These methods deal with configuration directories:

B<user_data_dir>,
B<site_data_dir>,
B<search_dirs>

=over 4

=item B<new> I<param-hash>

Creates a module object. Only one module instance may be created in the
program, since this object gets exclusive rights on communication with I<fvwm>.

The following parameters may be given in the constractor:

    Name          - used in module configuration and debugging
    Mask          - events a module is interested to receive
    XMask         - the same for extended events
    SyncMask      - events to lock on
    SyncXMask     - the same for extended events
    EnableAlias   - whether a module accepts an alias in command line
    EnableOptions - options that a module accepts in command line
    Debug         - 0 means no debug, 1 - user debug, 2,3,4 - perllib

Example:

    my $module = new FVWM::Module(
        Name => "FvwmPerlBasedWindowRearranger",
        Mask => M_CONFIGURE_WINDOW | M_END_WINDOWLIST,
        EnableOptions => { "animate" => \$a, "cascade" => \$c },
        Debug => 2,
    );

Event types needed for the 4 mask parameters are defined in B<FVWM::Constants>.

Set I<Debug> to 2 to nicely dump all communication with fvwm (sent commands
and received events). Setting it to 3 makes it even more verbose.

Some options cause an automatically parsing of the module command line args.
See L<Getopt::Long> for the format of the hash ref accepted by
I<EnableOptions> parameter. If boolean I<EnableAlias> parameter is given,
then the alias argument may be specified anywhere on the command line, for
example before or after long/short options or even in between, as long as
there are no conflicts with some non-mandatory option arguments. In which
case "--" may be used to indicate the end of the options. All non-parsed
command line arguments are available to the program using B<argv> method.

=item B<version>

Returns fvwm version string I<x.y.z>.

=item B<version_info>

Returns fvwm version info string, like " (from cvs)" or " (snap-YYYYMMDD)".
This string is usually empty for the final version.

=item B<argv>

Returns remaining module arguments (array ref) passed in the command line.
Arguments that are used for I<fvwm>-to-module communication are not included.
Arguments that are automatically parsed using I<EnableAlias> and/or
I<EnableOptions> specified in the constructor are not included.

=item B<send> I<command> [I<window-id>] [I<continue-flag>]

Sends I<command> back for execution. If the I<window-id> is specified this
command will be executed in this window context. I<continue-flag> of 0
signals that this is the last sent command from the module, the default
for this flag is 1.

=item B<track> [I<mode-hash>] [I<name>] [I<param-hash>]

Creates a module tracker object (see L<FVWM::Tracker>) specified
by a I<name>.

I<mode-hash> may include parameters:

    NoStart - true value means the created tracker is not auto-started
    NoReuse - true value means not to reuse any existing named tracker

I<param-hash> is specific to the tracker named I<name>. Every tracker class
(a subclass of B<FVWM::Tracker>) has its own manual page, contact it for
the tracker details and usage.

=item B<event_loop>

The main event loop. A module should define some event handlers using
B<add_handler> before entering the event loop. When the event happens all
event handlers registered on this event are called, then a module returns
to the event loop awaiting for new events forever.

This method may be finished when one of the following happens. 1) Explicit
B<terminate> is called in one of the event handlers. 2) Signal handler
(system signals are independent from this event loop) decides to I<die>.
This is usually catched and a proper shutdown is done. 3) An event handler
I<die>d, in this case the module aborts, this is done on purpose to
encourage programmers to fix bugs. 4) Communication with I<fvwm> closed, for
example B<KillModule> called or the main I<fvwm> process exited.

In all these cases (except for the third one) I<ON_EXIT> event handlers are
called if defined and then B<disconnect> is called. So no communication is
available after this method is finished. If you need a communication before
the module exits, define an I<ON_EXIT> event handler.

=item B<send_ready>

This is automatically called (if needed) when a module enters B<event_loop>,
but sometimes you may want to tell I<fvwm> that the module is fully ready
earlier. This only makes sence if the module was run using
B<ModuleSynchronous> command, in this case I<fvwm> gets locked until the module
sends the "ready" notification.

=item B<send_unlock>

When an event was configured to be sent to a module synchronously using
I<SyncMask> and I<SyncXMask>, I<fvwm> gets locked until the module sends
the "unlock" notification. This is automatically sent (if needed) when a
handler is finished, but sometimes a handler should release I<fvwm> earlier.

=item B<request_reply> I<text> [I<win_id>]

A module may request I<fvwm> to send the same text (but possibly
interpolated) back to it using MX_REPLY event. This method sends special
command I<Send_Reply>.

=item B<postpone_send> I<command> [I<window-id>] [I<continue-flag>]

The same like B<send>, but the actual command sending is postponed
until before the module enters the reading-from-fvwm phase in B<event_loop>.

=item B<terminate> [I<continue>]

This method is used for 2 purposed, usually in event handlers. To terminate
the entire event loop and to terminate only an execution of the current
handler if I<continue> is set.

=item B<reset_handlers>

This deletes all event handlers without exception.

=item B<add_handler> I<mask code>

Defines a handler (that is a I<code> subroutine) for the given I<mask> event
(or several events). Usually the event type is one of the fvwm I<M_*> or
I<MX_*> constants (see B<FVWM::Constants>), but it may also be I<ON_EXIT>,
this special event is called just before the event loop is terminated.

The I<mask> may include several events in the same category (the event types
are or-ed). In this case the handler will be called for every matching event.
Currently there are 3 categories: regular events (M_*), extended events (MX_*)
and special events (ON_EXIT). These 3 categories of events can't be mixed,
primary because of technical reasons.

The handler subroutine is called with these parameters:

    ($self, $event)

where C<$self> is a module object, C<$event> is B<FVWM::Event> object.

If the I<mask> includes more than one event type, use C<$event-E<gt>type>
to dispatch event types if needed.

The handler may call C<$self-E<gt>terminate> to terminate the event loop
completely or C<$self-E<gt>terminate("continue")> to terminate the current
event handler only. The second form is useful when the handler subroutine
calls other subroutines that need to terminate the primary one.

If several event handlers are added for the same event type, they are
executed in the added order. To forbid the further propagation of the
same event, an event handler may call C<$event-E<gt>propagation_allowed(0)>.

The return value from B<add_handler> is an identifier the only purpose of
which is to be passed to B<delete_handler> in case the newly defined handler
should be deleted at some point.

=item B<delete_handler> I<id>

Removes the handler specified by I<id>. The return value is 1 if the handler
is found and deleted, 0 otherwise.

=item B<add_default_error_handler>

This adds the default handler for I<M_ERROR> event. This class simply prints
an error message to the standard error stream, but subclasses may define
another default handler by overwriting this method.

=item B<debug> I<msg> [I<level>]

Prints I<msg> to the standard error stream if I<level> is greater or equal to
the module debug level defined using I<Debug> in the constructor. The default
I<level> for this method is 1 that makes it possible to add user debugging
output without specifying a level. The default module level is 0, so no
debugging output of positive levels is shown.

This module uses B<debug> internally (with I<level> 2) to dump all
incoming and outgoing communication data in B<send> and B<process_packet>.
Apparently this output is only seen if I<Debug> is set to 2 or greater.

=item B<show_error> I<msg>

Writes I<msg> to the error stream (stderr). It is supposed that the argument
has no traling end of line. May be used to signal non fatal error.

Subclasses may overwrite this method and, for example, show all error
messages in separate windows or in the common error window.

=item B<show_message> I<msg>

Writes I<msg> to the message stream (stderr). It is supposed that the argument
has no traling end of line. May be used to show a named output.

Subclasses may overwrite this method and, for example, show all
messages in separate windows or in the common message window.

=item B<show_debug> I<msg>

Unconditionally writes I<msg> to the debug stream (stderr). It is supposed
that the argument has no traling end of line. Used in B<debug> to actually
show the message when the level is matched.

Subclasses may overwrite this method and, for example, show all debugging
messages in separate windows or in the common debug window.

=item B<is_dummy>

Usually a module should be executed by I<fvwm> only. But to help creating
GUI applications, the dummy mode is supported when the module is started
from the command line. No events are received in this case, but with some
effort they may be emulated:

    $module->emulate_event(M_NEW_DESK, [ 2 ]) if $module->is_dummy;

=item B<internal_die> I<msg>

This may be used to end the module with the corresponding I<msg>.
For a clean module exit use B<show_error> and B<terminate> instead.

=item B<name> [I<name>]

Sets or returns the module name. Called automatically from the constructor.

=item B<mask> [I<mask>] [I<explicit-flag>]
=item B<xmask> [I<mask>] [I<explicit-flag>]

Sets or returns the module mask. Called automatically from the constructor.

Regular and extended event types should never be mixed, this is why there
are 2 variants of this method, the first is for regular and the second is
for extended event types. Without a parameter, the module mask is returned,
the integer parameter indicates a mask to set and the old mask is returned.

The module only receives the packets matching these 2 module masks (regular
and extended).

This class is smart to update the minimal module masks automatically if you
never set them explicitly (either in constructor or using these methods).
The I<explicit-flag> parameter should not be usually used, it defaults to 1.
If you set it to 0 then the module is informed to continue to automatically
update masks on the following B<add_handlers> calls even after the current
mask setting.

=item B<is_in_mask> I<type>

Returns true if the module mask matches the given I<type>.
Good for both regular and extended event types as long as they are queried
separately.

=item B<sync_mask> [I<mask>]
=item B<sync_xmask> [I<mask>]

The same as B<mask> and B<xmask>, but sets/returns the synchronization
mask of the module.

The module is synchronized with I<fvwm> on all packets matching these 2
module synchronization masks (regular and extended).

=item B<is_in_sync_mask> I<type>

Returns true if the module synchronization mask matches the given I<type>.
Good for both regular and extended event types as long as they are queried
separately.

=item B<disconnect>

This method invokes I<ON_EXIT> handlers if any and closes communication.
It is called automatically from B<event_loop> before finishing.
It is safe to call this method more than once.

This method may be called from signal handlers before I<exit>ing for the
proper shutdown.

=item B<get_handler_category> I<type>

Returns one of 3 string ids depending on the event handler I<type> that has
the same meaning as the corresponding packet type ("regular" or "extended")
with an addition of "special" category for I<ON_EXIT> handlers.

=item B<read_packet>

This is a blocking method that waits until there is a packet on the
communication end from I<fvwm>. Then it returns a list of 2 values,
packet type and packet data (unpacked array of arguments).

=item B<invoke_handler> I<event>

Dispatches the apropos event handlers with the event data.
This method is called automatically, so you usually should not worry about it.

=item B<process_packet> [I<type data>]

This method constructs the event object from the packet data and calls
B<invoke_handler> with it. Prints debug info if requested. Finally calls
B<send_unlock> if needed.

You should not really worry about this method, it is called automatically
from the event loop.

=item B<emulate_event> I<type data>

This method emulates the event as returned by B<read_packet>. The given event
is processed immediately if in the event loop, or just before the real
B<read_packet> otherwise.

The parameters are the same as in B<process_packet> and the same as in
L<FVWM::Event> constructor.

=item B<event_loop_prepared>

Called from B<event_loop> every time before reading the packet for new data.
Subclasses should pass this method the same arguments that B<event_loop>
received for a possible future use.

=item B<event_loop_finished>

Called from B<event_loop> just before the return.
Subclasses should pass this method the same arguments that B<event_loop>
received for a possible future use.

=item B<is_event_extended> I<type>

For technical reasons there are 2 categories of fvwm events, regular and
extended. This is done to enable more events. With introdution of the
extended event types (with the highest bit set) it is now possible to have
31+31=62 different event types rather than 32. This is a good point, the bad
point is that only event types of the same category may be masked (or-ed)
together. This method returns 1 or 0 depending on whether the event I<type>
is extended or not.

=item B<user_data_dir>

Returns the user data directory, usually ~/.fvwm or set by $FVWM_USERDIR.

=item B<site_data_dir>

Returns the system-wide data directory, the one configured when fvwm is
installed. It is also returned by `fvwm-config --fvwm-datadir`.

=item B<search_dirs>

It is a good practice for a module to search for the given configuration
in one of 2 data directories, the user one and the system-wide. This method
returns a list of both directories in that order.

=back

=head1 BUGS

Awaiting for your reporting.

=head1 CAVEATS

In keeping with the UNIX philosophy, B<FVWM::Module> does not keep you from
doing stupid things, as that would also keep you from doing clever things.
What this means is that there are several areas with which you can hang your
module or even royally confuse your running I<fvwm> process. This is due to
flexibility, not bugs.

=head1 AUTHOR

Mikhael Goikhman <migo@homemail.com>.

=head1 THANKS TO

Randy J. Ray <randy@byz.org>.

=head1 SEE ALSO

For more information, see L<fvwm>, L<FVWM::Module::Gtk> and L<FVWM::Module::Tk>,
L<FVWM::Tracker>.

=cut
