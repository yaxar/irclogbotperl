#!/usr/bin/env perl
#Now we are going to load all of what it needs.
use Mojolicious::Lite;
use EV;
use AnyEvent::IRC;
use AnyEvent::IRC::Client;
use DateTime;
#Below we will create a new AnyEvent::IRC instance
my $irc = AnyEvent::IRC::Client->new;
#Here we mark the default values
my $channel = "#mojo";
my $nick = "guest$$";
my $user = "guest$$";
my $real = "guest$$";
my $test = $channel;
my $server = 'irc.perl.org';
#This is the / funciton :)
get '/' => sub {
	my $self = shift;
	#making sure that we will connect with the latest info
	$nick = $self->param('nick') || $nick;
	$channel = $self->param('channel') || $channel;
	#sending the data to the template
	$self->stash(nick => $nick);
	#rendering the template
	$self->render('index', channel =>$channel);
	#changing our nick
	$irc->send_srv(NICK => $nick);
	#calling the change channel function
	channelr($channel);
};
#connecting to the irc server
$irc->connect($server, 6667, {nick => $nick, user => $user, real => $real});

sub channelr {
	my ($channel)  = @_;
	#here we check if the $channel is the same as $test or not
	if ($channel ne $test) {
		$irc->send_srv(JOIN => $channel);
		$irc->send_srv(PART => $test);
	}else{
		$irc->send_srv(JOIN => $channel);
	}
}
#here we update the log file
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
#this is where all the logic comes in :)
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
	# Emit "join" event for every new IRC join
	my $j = $irc->reg_cb(join => sub {
		my ($ls, $nick, $channel, $is_myself) = @_;
		my $message = "$nick joined the chat room.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	# Emit "nick_change" event for every new IRC nick_change
	my $nc = $irc->reg_cb(nick_change => sub {
		my ($ls, $ld_nick, $new_nick, $is_myself)  = @_;
		my $message = "$ld_nick changed his/her nickname to $new_nick.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	# Emit "quit" event for every new IRC quit
	my $qu = $irc->reg_cb(quit => sub {
		my ($sl, $nick, $msg)  = @_;
		my $message = "$nick left the chat room.\n";
		my $result = updatefile($channel, $message);
		$self->write("event:msg\ndata: $message\n\n");
	});
	# Here we finish it all of and unreg everything
	$self->on(finish => sub { 
		$irc−>unreg_cb($pm);
		$irc−>unreg_cb($j);
		$irc−>unreg_cb($nc);
		$irc−>unreg_cb($qu);
	});
};

app->start;
__DATA__

@@ index.html.ep
<!doctype html><html>
  <head>
  <title>The Perl IRC Server</title>
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
	<p>You can change the Nick or the Channel below but the Server, Real-Name and User you can't change :)</p>
	<form action="" type="POST">
		Nick: <input type="text" name="nick" value="<%= $nick %>" /><br />
		Channel: <input type="text" name="channel" value="<%= $channel %>" /><br />
		<input type="submit" value="Submit" />
	</form>
   <div id="currentcontent"></div>
  </body>
</html>
