#!/usr/bin/env perl
use Mojolicious::Lite;
use EV;
use AnyEvent::IRC;
use AnyEvent::IRC::Client;
use DateTime;
use Config::Tiny;
# Join #mojo on irc.perl.org
my $irc = AnyEvent::IRC::Client->new; 
my $configfile = 'config.conf';
unless(-e $configfile){
open FH, ">$configfile";
print FH '{
    nick	=> "guest$$",
    user	=> "guest$$",
    real	=> "guest$$",
    server	=> "irc.freenode.net",
    channel => "#maxson"
  };';
close FH; 
}
my $config = plugin Config => {file => 'config.conf', stash_key => 'conf'};
my $channel = "#maxson";
my $nick = "guest$$";
my $user = "guest$$";
my $real = "guest$$";
my $server = 'irc.freenode.net';
my $test = $channel;
sub configr{
	my $self = shift;
	$nick = $self->config('nick');
	$user = $self->config('user');
	$real = $self->config('real');
	$channel = $self->config('channel');
	$server = $self->config('server');
}


#my $config = plugin 'Config';
#my $config => {default => {foo => 'bar'}};
#my $config => {stash_key => 'conf'};
get '/' => sub {
	my $self = shift;
	$config->{'nick'} = $self->param('nick') || "guest$$";
	$config->{'user'} = $self->param('user') || "guest$$";
	$config->{'real'} = $self->param('real') || "guest$$";
	$config->{'channel'} = $self->param('channel') || '#maxson';
	$config->{'server'} = $self->param('server') || 'irc.freenode.net';
	$self->stash(nick => $self->config('nick'));
	$self->stash(user => $self->config('user'));
	$self->stash(real => $self->config('real'));
	$self->render('index', channel =>$self->config('channel'));
	$irc->send_srv(JOIN => $self->config('channel'));
	$irc->send_srv(PART => $test);
	$irc->send_srv(NICK => $self->param('nick'));
};
$irc->connect('irc.freenode.net', 6667, {nick => $nick, user => $user, real => $real});


sub channeld {
	my ($channel)  = @_;
	if (defined($channel)) {
		$channel = $channel;
	}else{
		$channel = '#maxson';
	}
	return $channel;
}
sub updatefile {
	my ($channel, $message)  = @_;
	my $dt = DateTime->now;
my $ymd    = $dt->ymd; 
	my $dir = $channel;
	unless(-d $dir){
		mkdir $dir or die;
	}
	my $filename = $channel . '/' . $ymd;
	open(my $n, ">>", $filename)
		or die "cannot open append output.txt: $!";
	print $n "$message \n";
}
get '/events' => sub {
	my $self = shift;
	Mojo::IOLoop->stream($self->tx->connection)->timeout(300000000);
	$self->write("event:r\ndata:     mmmm\n\n");
	# Emit "msg" event for every new IRC message
	$self->res->headers->content_type('text/event-stream');
	my $pm = $irc->reg_cb( publicmsg     => sub {
		my ($foo, $channel, $ircmsg ) = @_;
		my $message = $ircmsg->{params}->[1];
		my $user = $ircmsg->{prefix};
		my $userid = $ircmsg->{prefix};
		my $nick = AnyEvent::IRC::Util::prefix_nick($user);
		$message = $nick . ': ' . $message;
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	my $j = $irc->reg_cb(join => sub {
		my ($ls, $nick, $channel, $is_myself) = @_;
		my $message = "$nick joined the chat room.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	my $nc = $irc->reg_cb(nick_change => sub {
		my ($ls, $ld_nick, $new_nick, $is_myself)  = @_;
		my $message = "$ld_nick changed his/her nickname to $new_nick.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	my $qu = $irc->reg_cb(quit => sub {
		my ($sl, $nick, $msg)  = @_;
		my $message = "$nick left the chat room.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	$self->on(finish => sub { 
				undef $pm;
				undef $j;
				undef $nc;
				undef $qu;
	});
};

app->start;
__DATA__

@@ index.html.ep
<!doctype html><html>
  <head>
  <title>The Mojolicious IRC channel</title>
  <style type="text/css">
#currentcontent
{
width:330px;
height:300px;
overflow:hidden;
margin-left: auto; margin-right: auto;
padding:10px;
border:5px solid gray;
}
</style>
  <script src="http://code.jquery.com/jquery-1.7.1.min.js"></script>
  <script>
      var events = new EventSource('<%= url_for 'events' %>');
      // Subscribe to "msg" event
      events.addEventListener('msg', function(event) {
        $("#currentcontent").prepend(document.createTextNode(event.data));
        //$('div.dd').css({'display':'inline', 'clear':'both'});
        $("#currentcontent").prepend('<br />');
      }, false);
       events.addEventListener('r', function(event) {
      }, false);
    </script>
  </head>
  <body>
	<div id="content">Below is the current content of the channel <%= $channel %></div>  
	<p>You can change the any of the value's bellow.</p>
	<form action="" type="POST">
		Nick: <input type="text" name="nick" value="<%= $nick %>" /><br />
		User: <input type="text" name="user" value="<%= $user %>" /><br />
		Real Name: <input type="text" name="real" value="<%= $real %>" /><br />
		Channel: <input type="text" name="channel" value="<%= $channel %>" /><br />
	<input type="submit" value="Submit" />
	</form>
   <div id="currentcontent"></div>
  </body>
</html>
