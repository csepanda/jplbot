#!/usr/local/bin/perl
# made by: KorG
use strict;
use warnings;
use v5.18;
no warnings 'experimental';
use utf8;

use Net::Jabber::Bot;
use Storable;
use LWP;

# DEFAULT VALUES, don't change them here
# See comments in the 'config.pl'
our $name = 'AimBot';
our $karmafile = '/tmp/karma';
our $saytofile = '/tmp/sayto';
our $sayto_keep_time = 604800;
our $server = 'zhmylove.ru';
our $port = 5222;
our $username = 'aimbot';
our $password = 'password';
our $loop_sleep_time = 60;
our $conference_server = 'conference.jabber.ru';
our %forum_passwords = ('ubuntulinux' => 'ubuntu');
our @colors = (
   'бело-оранжевый', 'оранжевый',
   'бело-зелёный', 'зелёный',
   'бело-синий', 'синий',
   'бело-коричневый', 'коричневый',
);
our $colors_minimum = 3;
our $sayto_max = 128;

unless (my $ret = do './config.pl') {
   warn "couldn't parse config.pl: $@" if $@;
   warn "couldn't do config.pl: $!" unless defined $ret;
   warn "couldn't run config.pl" unless $ret;
}

srand;
store {}, $karmafile unless -r $karmafile;
my %karma = %{retrieve($karmafile)};
store {}, $saytofile unless -r $saytofile;
my %sayto = %{retrieve($saytofile)};
my %jid_DB = ();
my %bomb_time;
my %bomb_correct;
my %bomb_resourse;
my %bomb_nick;
my $last_bomb_time = 0;
my $col_count = int($colors_minimum + ($#colors - $colors_minimum + 1) * rand);
my %col_hash;
my %forum_list;
$col_hash{lc($_)} = 1 for @colors;
$forum_list{$_} = [] for keys %forum_passwords; # [] due to Bot.pm.patch

my $qname = quotemeta($name);
my $bot_address = "https://github.com/tune-it/jplbot";
my $rb = "[\x{20}\x{22}\x{26}\x{27}\x{2f}\x{3a}\x{3c}\x{3e}\x{40}]";
my $rB = "[^$rb]";
$SIG{INT} = \&shutdown;
$SIG{TERM} = \&shutdown;
binmode STDOUT, ':utf8';

sub shutdown {
   store \%karma, $karmafile and say "Karma saved to: $karmafile";
   store \%sayto, $saytofile and say "Sayto saved to: $saytofile";
   exit 0;
}

sub say_to {
   my ($bot, $room, $dst) = @_;

   return unless (defined $sayto{$room} && defined $sayto{$room}->{$dst});

   foreach my $src (keys $sayto{$room}->{$dst}) {
      $bot->SendPersonalMessage("$room\@$conference_server/$dst",
         "Тебе писал $src: [" . $sayto{$room}->{$dst}->{$src}->{'text'});

      delete $sayto{$room}->{$dst}->{$src};

      delete $sayto{$room}->{$dst} unless scalar keys $sayto{$room}->{$dst};
   }
}

sub bomb_user {
   my ($bot, $user) = @_;
   my $to = $bomb_resourse{lc($user)};
   my $nick = $bomb_nick{lc($user)};

   delete $bomb_time{lc($user)};
   delete $bomb_correct{lc($user)};
   delete $bomb_resourse{lc($user)};
   delete $bomb_nick{lc($user)};

   return unless $bot->IsInRoom((split '@', $to)[0], $nick);

   $bot->SendGroupMessage($to, "$nick: ты взорвался!");

   my $xml = "<iq from='$username\@$server/$name' id='korg1' to='$to' " .
   "type='set'><query xmlns='http://jabber.org/protocol/muc#admin'><item " .
   "nick='$nick' role='none'><reason>Bombed!</reason></item></query></iq>";

   $bot->jabber_client->SendXML($xml);
}

sub background_checks {
   my $bot = shift;
   store \%karma, $karmafile;

   foreach(keys %bomb_time){
      bomb_user($bot, $_) if (time >
         $bomb_time{lc($_)} + $loop_sleep_time);
   }

   foreach my $room (keys %forum_passwords) {
      foreach my $dst (keys $sayto{$room}) {
         foreach my $src (keys $sayto{$room}->{$dst}) {
            delete $sayto{$room}->{$dst}->{$src} if ( time >
               $sayto{$room}->{$dst}->{$src}->{'time'} + $sayto_keep_time
            );
         }

         delete $sayto{$room}->{$dst} unless scalar keys $sayto{$room}->{$dst};
      }
   }
}

sub new_bot_message {
   my %msg = @_;
   my $bot = $msg{'bot_object'};

   my ($resource, $from) = split '/', $msg{'from_full'};
   my $forum = (split '@', $resource)[0];

   my $to_me = ($msg{'body'} =~ s{^$qname: }{});

   if ($msg{'type'} eq "chat") {
      $bot->SendPersonalMessage($msg{'reply_to'},
         "Я не работаю в привате. Если Вы нашли проблему, " .
         "у Вас есть предложения или пожелания, пишите issue на $bot_address");
      return;
   }

   given ($msg{'body'}) {

      when (/^(?:date|дата)\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: " . localtime);
      }

      when (/^(?:time|время)\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: " . time);
      }

      when (/emacs/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "use vim or die;") if int(2*rand);
      }

      when (/sudo/) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "sudo нинужно >_<") if int(2*rand);
      }

      when (/(?:ubunt|убунт)/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "убунта нинужна >_<") if int(2*rand);
      }

      when (/^help\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: я написал тебе в личку");

         $bot->SendPersonalMessage($msg{'reply_to'} . "/$from",
            "Краткая справка: \n" .
            " bomb        nick      -- установить бомбу\n" .
            " date                  -- вывести дату\n" .
            " fortune               -- вывеси цитату\n" .
            " karma       nick      -- вывести карму\n" .
            " sayto      /nick/text -- сказать пользователю\n" .
            " time                  -- вывести время\n" .
            "\n" .
            "Вопросы и предложения: $bot_address\n" .
            "В благодарность вы можете нажать Star на странице проекта. " .
            "Это совершенно бесплатно\n" .
            "Чмоки ;-)"
         );
      }

      when (/^(?:fortune|ф)\s*$/i) {
         my $fortune = `/usr/games/fortune -s`;
         chomp $fortune;
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: $fortune");
         sleep 1;
      }

      when (/^(?:karma|карма)\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: твоя карма: " . ($karma{lc($from)}||0));
      }

      when (/^(?:bomb|бомба)\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: бомба -- это не игрушки!");
      }

      when (m{(https?://\S+)}) {
         my $uri = $1;
         my $ua = LWP::UserAgent->new();
         my %type;
         $ua->timeout(10);
         $ua->env_proxy;
         $ua->agent('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:46.0)' .
            'Gecko/20100101 Firefox/46.0');

         $ua->add_handler(response_header => sub {
               my $response = shift;

               if (scalar $response->code >= 400) {
                  $bot->SendGroupMessage($msg{'reply_to'},
                     "$from: сервер вернул код: " .
                     $response->code . ", разбирайся сам!");

                  die;
               }

               foreach($response->header("Content-type")){
                  given ($_) {
                     when (m{^text/html} || /korg/) { $type{'html'}++; }
                     when (m{^image/}) { $type{'image'}++; }
                  }
               }

               if ($type{'image'}) {
                  my $length = $response->header('Content-Length');
                  $length = -1 unless $length > 0;

                  while($length=~s/(?<=\d)(?=\d{3}\b)/ /){}

                  $bot->SendGroupMessage($msg{'reply_to'},
                     "$from: Content-Length: $length байт.");

                  die;
               }
            });

         $ua->add_handler(response_done => sub {
               my $response = shift;

               if ($type{'image'}) {
                  # do nothing for all other chunks of response
               } elsif ($type{'html'}) {
                  my $content = $response->decoded_content;

                  return if scalar $response->code < 200 || 
                  scalar $response->code >= 300;

                  $content =~ m{.*<title[^>]*>(.*?)</title.*}si;

                  my $title = defined $1 ? $1 : "";

                  if ($title eq "") {
                     $title = $uri;
                     $title =~ s{^https?://([^/]+)/.*$}{$1};
                  }

                  $bot->SendGroupMessage($msg{'reply_to'},
                     "$from: заголовок: [$title]");
               } else {
                  $bot->SendGroupMessage($msg{'reply_to'},
                     "$from: да ну нафиг это парсить...");
               }
            });

         my $response = $ua->get($uri);
      }

      when (/^test$/) {
         return unless defined $sayto{$forum};

         foreach my $src (keys $sayto{$forum}) {
            say $src;
            foreach my $dst (keys $sayto{$forum}->{$src}) {
               say " $dst";
               say "  " . $sayto{$forum}->{$src}->{$dst}->{'text'};
               say "  " . $sayto{$forum}->{$src}->{$dst}->{'time'};
            }
         }
      }

      when (m{^sayto[^/]*/([^/]*)/(.*)$}s) {
         my $sayto_to = $1;
         my $sayto_txt = $2;

         if ($bot->IsInRoom($forum, $sayto_to)) {
            $bot->SendGroupMessage($msg{'reply_to'},
               "$sayto_to: смотри, тебе пишет $from!");

            return;
         }

         if (defined $sayto{$forum}) {
            if (scalar keys $sayto{$forum} > $sayto_max) {
               $bot->SendGroupMessage($msg{'reply_to'},
                  "$from: у меня кончилось место :(");

               return;
            }

            if (defined $sayto{$forum}->{$sayto_to}->{$from} &&
               defined $sayto{$forum}->{$sayto_to}->{$from}->{'text'}) {
               $bot->SendGroupMessage($msg{'reply_to'},
                  "$from: предыдущее значение: [" .
                  $sayto{$forum}->{$sayto_to}->{$from}->{'text'} .
                  "]");
            }
         }

         $sayto{$forum}->{$sayto_to}->{$from} = {
            'text' => $sayto_txt,
            'time' => time,
         };

         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: замётано.");
      }

      when (/^(?:(?:добро|все|ребя)\w*)*\s*утр/i || /^утр\w*\s*[.!]*\s*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: и тебе доброе утро!");
      }

      when (/^ку[\s!]*\b/i || /^(?:всем\s*)?прив\w*[.\s!]*$/i ||
         /^здаро\w*\s*/) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "Привет, привет!");
      }

      when (/^пыщь?(?:-пыщь?)?[.\s!]*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: пыщь-пыщь, дави прыщь!");
      }

      when (/^(?:доброй|спокойной|всем)?\s*ночи[.\s!]*$/i ||
         /^[\w.,\s]*[шс]пать[.\s!]*$/i) {
         $bot->SendGroupMessage($msg{'reply_to'},
            "Сладких снов!");
      }

      when (sub{return $col_hash{lc($_)} || 0}) {
         return unless defined $bomb_correct{lc($from)};

         if ($bomb_correct{lc($from)} eq $msg{'body'}) {
            delete $bomb_time{lc($from)};
            delete $bomb_correct{lc($from)};
            delete $bomb_resourse{lc($from)};
            delete $bomb_nick{lc($from)};
            $bot->SendGroupMessage($msg{'reply_to'},
               "$from, расслабься, это был всего-лишь розыгрыш!");
         } else {
            bomb_user($bot, $from);
         }
      }

      default {
         # manual check for nick presence, performance hack
         foreach my $nick (keys $jid_DB{$forum}) {
            my $qnick = quotemeta($nick);

            if (" $msg{body} " =~ m{$rb$qnick$rb}i) {

               given ($msg{'body'}) {

                  when (/^(?:karma|карма)$rb*?$qnick\s*?$/i) {
                     $bot->SendGroupMessage($msg{'reply_to'},
                        "$from: карма $nick " . ($karma{lc($nick)}||0));
                  }

                  when (/^(?:bomb|бомба)$rb*?$qnick\s*?$/i) {
                     if ($from eq $nick) {
                        $bot->SendGroupMessage($msg{'reply_to'},
                           "$from: привык забавляться сам с собой?");
                        return;
                     }

                     if (defined $bomb_time{lc($nick)}) {
                        $bot->SendGroupMessage($msg{'reply_to'},
                           "$from: на $nick уже установлена бомба.");
                        return;
                     }

                     if (abs(time - $last_bomb_time) < 180) {
                        $bot->SendGroupMessage($msg{'reply_to'},
                           "$from: у меня ещё не восполнен боезапас. Жди.");
                        return;
                     }

                     $last_bomb_time = time;

                     my %selected_colors;
                     while($col_count != keys %selected_colors){
                        $selected_colors{$colors[int($#colors * rand)]} = 1;
                     }

                     my $selected_colors_t = join ', ', (
                        sort keys %selected_colors
                     );

                     $selected_colors_t =~ s/,( \S+)$/ и$1/i;

                     $bomb_time{lc($nick)} = time;
                     $bomb_correct{lc($nick)} = (keys %selected_colors)[0];
                     $bomb_resourse{lc($nick)} = $resource;
                     $bomb_nick{lc($nick)} = $nick;

                     my $txt = "Привет от $from, $nick! " .
                     "Я хочу сыграть с тобой в игру.\n" .
                     "Правила очень простые. " .
                     "Всю свою жизнь ты не уважал random, " .
                     "и теперь пришло время поплатиться. \n" .
                     "На тебе бомба, из которой торчат " .
                     "$selected_colors_t провода. \n" .
                     "Твоя задача -- правильно выбрать провод. " .
                     "До взрыва осталось 1-2 минуты. Время пошло!";

                     $bot->SendGroupMessage($msg{'reply_to'}, $txt);
                  }

                  when (/^($qnick):\s*\+[+1]+\s*$/) {
                     return if $nick eq $from;
                     $karma{lc($nick)}++;
                     $bot->SendGroupMessage($msg{'reply_to'},
                        "$from: поднял карму $nick до " . $karma{lc($nick)});
                  }

                  when (/^($qnick):\s*\-[-1]+\s*$/) {
                     return if $nick eq $from;
                     $karma{lc($nick)}--;
                     $bot->SendGroupMessage($msg{'reply_to'},
                        "$from: опустил карму $nick до " . $karma{lc($nick)});
                  }
               }

               return;
            }
         }

         $bot->SendGroupMessage($msg{'reply_to'},
            "$from: how about NO, братиша?") if $to_me;
      }
   }
}

my $bot = Net::Jabber::Bot->new(
   server => $server,
   conference_server => $conference_server,
   port => $port,
   username => $username,
   password => $password,
   alias => $name,
   resource => $name,
   safety_mode => 1,
   message_function => \&new_bot_message,
   background_function => \&background_checks,
   loop_sleep_time => $loop_sleep_time,
   forums_and_responses => \%forum_list,
   forums_passwords => \%forum_passwords,
   JidDB => \%jid_DB,
   SayTo => \&say_to,
   SayToDB => \%sayto,
);

$bot->Start();
