#!/usr/bin/perl -w
use strict;

# This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
# http://creativecommons.org/licenses/by-nc-sa/4.0/
# Authors: Evgeny Chukharev-Hudilainen, Nazlinur Gokturk Tuney

use SDS;

sds_init("Joanna");

sub pick {
  my $arr = shift;
  my $keep = shift;
  return '' if ref $arr ne 'ARRAY' || !@$arr;
  my $p = $keep ? ($arr->[int rand @$arr]) : (splice @$arr, int rand @$arr, 1);
  return $p;
}

sub fisher_yates_shuffle {
  my $array = shift;
  my $i = @$array;
  while ( --$i ) {
    my $j = int rand( $i+1 );
    @$array[$i,$j] = @$array[$j,$i];
  }
}

my $human_names = {
  solution_online => 'online resources',
  solution_tutor => 'a tutor',
  solution_drop => 'dropping class',
  solution_group => 'study groups',
  'abundant-information' => 'access to information',
  'ask' => 'asking questions',
  'content-familiarity' => 'knowing the content',
  'cooperation' => 'cooperation',
  'credible' => 'credibility',
  'face-to-face' => 'face-to-face interaction',
  'focus' => 'staying focused',
  'frustration' => 'avoiding frustration',
  gpa => 'GPA',
  independent => 'independence',
  money => 'money',
  'one-on-one' => 'working one-on-one',
  'time' => 'time'
};

my $regexp = {
  'solution_tutor' => sub {/\btutor(s|ing|ed)?\b|\bhir(e|ing|ed)\b/},
  'solution_drop' => sub {/\b(dropp?|quitt?)(ed|ing|s)?\b/},
  'solution_group' => sub {/group|team/},
  'solution_online' => sub {/online|forum|web|internet|technology|computer|google|tutorial /},
  
  'abundant-information' => sub { /(a lot of|lots of|many|much|more|tons of) (information|tutorials?|resources?|videos?|sources?)/ || /(dig|look through|scan)/ && /(information|tutorials|resources|sources)/ },
  'ask' => sub { /(ask|answer|discuss|have) (\w+ )?questions?/ || /(get|find|locate|look for) (\w+ )?answers?/ || /questions? answered/ },
  'choice' => sub { /(choose|decide|decision|choice|alternative|option)/ },
  ### know a little bit of the material
  'content-familiarity' => sub { /(great|more|much|a lot|lots of) (experience|knowledge)/ || /(practice|familiar with)/ || /no problem with (\w+ )?(class|content|material|program|software|stat)/ },
  'cooperation' => sub { /(help|support) (each other|other|friend|classmate|fellow|peer|student)/ || /(request|offer|ask for|get) help/ || /cooperative/ || /help with/ || /together/ },
  'credible' => sub { /(credible|reliable|trustable|knowledgable)/ || /\bgrad (student|people)/ || /\bgrads?\b/ || /(school|library) (resource|website|source)/ },
#  'experience' => sub {/(my|similar) experience/},
  'face-to-face' => sub {/(face to face|personable|interactive)/ || /(interact with|talk to|work with|study with)/ || /sit.* in front of|star.* at/ || /interaction/ || /computer in front of you/ || /look at the screen/ || (/social/ && !/social science/) },
  'focus' => sub {/social|distract|concentrat|party|chat|attention|focus/ || /stay.* on topic/},
  'friend' => sub {/classmate|friend|peer|fellow/},
  'frustration' => sub {/frustrat|depress|annoy|disappoint|confus|humiliat|embarrass|discourag|demotivat|anxious|lonely|stress|struggle|trouble|motivat/ },
  'gpa' => sub {/gpa|grade/i},
  'independent' => sub {/independent|on your own/}, #|yourself
  'money' => sub {/\b(afford|expens|cheap|cost|finance|price|funding|grant|free|money|pay|tuition|job|rent)/}, #hire
  'one-on-one' => sub {/one on one/},
  'professor' => sub {/professor|instructor|lecturer|teacher/},
  #'schoolwork' => sub {/project|thesis|assignment|homework|course|class|department|school|graduati|survive|fail|pass|review/},
  'time' => sub {/\b(time|busy|hours|ages|schedul|arrang|take very long)\b/},
  # time merged with schedule
};


my $arguments = {
  solution_online => {
    'ask' => [
      "-you don't have anyone to answer your questions when you search online",
      "+you can post your questions to an online forum",
    ],
    'cooperation' => [
      "-you can't get any help from real people",
    ],
    'money' => [
      '+online resources are free',
    ],
    'abundant-information' => [
      '+you can find a lot of information online',
      '-you have to dig through a lot of resources online'
    ],
    'credible' => [
      '-there are a lot of online resources that are not very credible',
      "+the school library offers a lot of credible websites that you can use"
    ],
    'face-to-face' => [
      "-it's not fun to sit in front of the computer with no face-to-face interaction",
      "+you might focus better without another person present",
    ],
    'focus' => [
      "+you can focus on your own questions and look for the information you need online",
      "-it can be hard to focus with all the distracting websites easily available on the internet",
    ],
    'frustration' => [
      "-the student will be very frustrated while searching online",
      "+the student would get answers quickly from online resources and be less frustrated with the course"
    ],
    'independent' => [
      "+you do not have to rely on other people",
      "-the student won't be directed if they are working independently",
    ],
    'one-on-one' => [
      "-you are not getting one-on-one help when you are searching online",
      "+the student might not want one-on-one help so online resources would be good",
    ],
    'time' => [
      "-searching online is very time-consuming",
      "+you can search online at any time that works for you"
    ]
  },

  solution_tutor => {
    'ask' => [
      "+you can ask your questions directly to your tutor"
    ],
    'cooperation' => [
      "+you can work together to learn the program"
    ],
    'money' => [
      '-hiring a tutor might be expensive',
      '-not everybody can afford a tutor'
    ],
    'abundant-information' => [
      '+tutors are very knowledgeable about different software programs'
    ],
    'credible' => [
      "+you can trust a tutor who is knowledgeable in the subject",
      "+graduate students can be a really credible resource",
    ],
    'face-to-face' => [
      "+face-to-face interaction with a tutor can be very helpful",
    ],
    'focus' => [
      "+the tutor can help you stay focused",
      "+with a tutor, you can focus on your own learning"
    ],
    'frustration' => [
      "+tutors typically help students avoid frustration",
    ],
    'independent' => [
      "-you have to be dependent on the tutor's schedule",
    ],
    'one-on-one' => [
      "+you can get one-on-one attention from a knowledgeable tutor"
    ],
    'time' => [
      "+you can save a lot of time by working with the tutor"
    ]
  },

  solution_group => {
    'abundant-information' => [
      "+your classmates might have a lot of useful information to share",
      "-working in a group means you need to review a lot of material you might already know",
    ],
    'ask' => [
      "+you can easily ask you questions to a group member",
      "-it can be confusing when lots of people try to answer your question at once in a study group",
    ],
    'choice' => [
      "+you can choose your own group members for a study group",
      "-all the group members you pick might be friends so you won't be very focused on the course material",
    ],
    'content-familiarity' => [
      "+there is always someone in the class who knows the content really well",
      "-the classmates are just students and might not understand much more than you do",
    ],
    'cooperation' => [
      "+the whole study group can work together to solve a problem quickly",
      "-some group members can make decisions take forever because they don't cooperate",
    ],
    'credible' => [
      "-sometimes no one in the study group knows the correct answer",
      "-another student might explain something all wrong and then you have to relearn it later",
    ],
    #'experience' => [
    #  "+I have had good experiences with a study group when I took a difficult course",
    #  "-once I had a terrible study group that was a complete waste of time",
    #],
    'face-to-face' => [
      "+you can work face-to-face with you group members",
      "-it can be embarassing to ask for help in person",
    ],
    'focus' => [
      "+you have other group members nearby who can make sure you are focused",
      "-other people might distract you or the whole group",
    ],
    'friend' => [
      "+you can spend more time with friends when you work together in a study group",
      "-the student might be embarassed to ask a friend for help with something",
    ],
    'frustration' => [
      "+you can share your frustration with others so you dont feel as bad",
      "-you might get frustrated if the study group isn't helpful right away",
    ],
    'gpa' => [
      "+the student can work hard with a study group this semester and still get a good grade in the class",
      "-the student has already failed a large exam and a study group won't help his grade enough",
    ],
    'independent' => [
      "+the student can rely on others for help",
      "-the student might like working alone better",
    ],
    'money' => [
      "+a study group is free to organise",
      "-study groups can take a lot of time and time is money",
    ],
    'one-on-one' => [
      "+the student could work with just one group member at a time",
      "-a study group isn't one-on-one help",
      "-all the students in the study group would need to help each other so there's no one-on-one help", 
    ],
    'professor' => [
      "+you don't have to ask the professor direct questions which is intimidating for some people",
    ],
    'schoolwork' => [
      "+you can get help with your schoolwork in the study group",
#      "-study grous can take a lot of time away from doing other schoolwork",
    ],
    'time' => [
      "+you can learn a lot from the group pretty quickly",
      "-it can be hard to schedule a time that works for all the group members",
    ]
  },

  solution_drop => {
    'content-familiarity' => [
      "+if the student drops the class, he will be already familiar with the content when he takes it later",
      "-if the student drops the class, the student won't know any content from the second part of the course",
    ],
    #'experience' => [
    #  "+I dropped a course once because I didn't have enough time that semester to do all the homework",
    #  "-I knew a person who had to drop a lot of classes because she was failing and that person stopped going to university afterwards",
    #],
    'focus' => [
      "+the student can focus on other coursework this semester",
      "-the student will have a lot to focus on next semester",
    ],
    'gpa' => [
      "+the class won't affect the student's gpa if he drops",
      "+the student would have a higher gpa without the low score in the statistics class if her drops",
      "+dropping the class would mean protecting a high gpa for the future",
    ],
    'professor' => [
      "+the student has already talked to the professor so visiting him to drop the course could be easier",
      "-the student might be embarassed to tell the instructor that he is dropping the class",
    ],
    #'schoolwork' => [
    #  "+the student will have less schoolwork to do",
    # "-the student may have to do more schoolwork in the future if he drops the class this semester",
    #],
    'time' => [
      "+if the student drops the class, he will have plenty of time to learn the course material without the pressure of grades",
      "+if the student drops the class, he will have time this semester to get a job or sudy other subjects if he drops",
      "-if the student drops the class, the student will have less time next semester when he has to write a thesis and take the additional class",
    ]
  }
};

my $ambivalents;

my $links = {
  ok => [ # avoid "yes"
    "I see",
    "OK",
    "I understand",
    "I see what you mean",
    "Sure",
    "I think I understand",
    "Indeed"
  ],
  yes => [
    "I agree that",
    "I think we both agree that",
    "Yes, I agree that"
  ],
  but => [
    "but I believe",
    "but I also think",
    "but on the other hand",
    "but"
  ],
  and => [
    "and",
    "and also",
    "and at the same time",
    "in addition",
    "along the same lines"
  ],
  and_negative => [
    "it is great, because for example",
    "it is nice, because for instance",
    "it is good, because",
  ],
  positive => [
    "I think it's great that",
    "It is certainly good that",
    "Fortunately"
  ],
  negative => [
    "Unfortunately",
    "It is not ideal that",
    "Sadly"
  ],
  question => [
    "Would you agree?",
    "What do you think?"
  ],
  question_solution => [
    "Would that solution be better then?",
    "Would that be the way to go then?",
    "Would that be a better option then?",
  ],
  switch => [
    "Well,",
    "OK, I think",
    "I just realized that",
    "It seems to me that",
    "I believe",
    "My thought was that",
    "I was just thinking: perhaps",
    "In my mind,",
    "Isn't it that",
  ],
  request_expand => [
    "I am not sure. Could you please tell me more about what you think?",
    "Well, could you tell me what other thoughts you have?",
    "Sorry, I don't think I am following you. Which solution are you arguing for?",
  ],
  counter_negative => [
    "Right, <argument> is important. Then <solution> might not be a good idea.",
    "Since you mention <argument>, it makes me think about <solution>, because",
    "Now that you mention <argument>, I don't think <solution> would work."
  ]
};


foreach my $solution (keys %$arguments) {
  foreach my $argument (keys %{$arguments->{$solution}}) {
    my ($p, $n);
    foreach my $response (@{$arguments->{$solution}{$argument}}) {
      $p++ if $response =~ /^\+/;
      $n++ if $response =~ /^\-/;
    }
    if ($p && $n) {
      $ambivalents->{$solution}{$argument}=1;
    }
  }
}
      
sub classify {
  my $text = shift;
  my @detected;
  foreach my $r (keys %$regexp) {
    my $sub = $regexp->{$r};
    local $_ = $text;
    my $res = $sub->();
    if ($res) {
      push @detected, $r;
    }
  }
  return \@detected;
}

my $solution = '';

my $cnt=0;

my $drop;
my $group;

my @prompts_second = (
  "OK, I understand that one solution was <solution>. Can you tell me what the other solution was?",
  "Are you sure you don't remember what the second solution was about?",
  "So the first solution was <solution>. And the second one?"
);

my @prompts_first = (
  "I am sorry, could you please say again what solutions you learned about?",
  "I am really sorry, I didn't get that. Could you please tell me again what two solutions you learned about?",
  "Sorry, could you say that one more time?"
);


say("OK, so we have four options: dropping the class, joining a study group, hiring a tutor, and using online resources. Which of these four solutions do you think would work best for the student?");

while ($cnt<6) {
  $cnt++;
  my $r = hear();
  my @labels = @{classify($r)};
  print "Understood: @labels\n";
  my @solutions = grep { /^solution_/ } @labels;
  my %solutions = map { $_ => 1 } @solutions;
  
  $solution = pick(\@solutions) || $solution;

  my @arguments = grep { !/^solution_/ } @labels;
  
  my %counter_arguments_for_solution = %{$arguments->{$solution} || {}};
  my %confirming_arguments_for_solution;
  foreach (@arguments) {
    $confirming_arguments_for_solution{$_} = $counter_arguments_for_solution{$_};
    delete $counter_arguments_for_solution{$_};
  }
  
  my @possible_counter_arguments = keys %counter_arguments_for_solution;
  my $counter_argument = pick(\@possible_counter_arguments);
  
  my @possible_confirming_arguments = keys %confirming_arguments_for_solution;

  my @possible_counter_solutions;
  foreach (keys %$regexp) {
    push @possible_counter_solutions, $_ if /^solution_/ && !$solutions{$_}
  }

  my $response = '';
  my $move = '';

  foreach my $cs (@possible_counter_solutions) {
    last if $response;
    foreach my $arg (@possible_confirming_arguments) {
      next if $ambivalents->{$cs}{$arg};
      next if !$arguments->{$solution}{$arg}[0];
      $arguments->{$solution}{$arg}[0] =~ /^(.)/;
      my $stance = $1;
      my $counter_stance = $stance eq '+' ? '-' : '+';
      my @options;
      foreach my $r (@{$arguments->{$cs}{$arg}}) {
        if ($r =~ s/^\Q$counter_stance\E//) {
          push @options, $r;
        }
      }
      if (@options) {
        my $r1 = pick(\@options);
        if ($stance eq '-') {
          $response = pick($links->{switch}).' '.$r1;
          $solution = $cs;
          $move = 'counter_solution';
        } else {
          $response = pick($links->{counter_negative}).' '.pick($links->{switch}).' '.$r1;
          $response =~ s/<solution>/$human_names->{$cs}/g;
          $response =~ s/<argument>/$human_names->{$arg}/g;
          $move = 'counter_negative';
        }
        last;
      }
    }
  }

  if (!$response) {
    my $confirming_argument = pick(\@possible_confirming_arguments);

    my $say_confirming_argument = pick($arguments->{$solution}{$confirming_argument});
    my $say_counter_argument = pick($arguments->{$solution}{$counter_argument});

    my $confirming_stance = '';
    $confirming_stance = $1 if $say_confirming_argument =~ s/^(.)//;
    
    my $counter_stance = '';
    $counter_stance = $1 if $say_counter_argument =~ s/^(.)//;

    my $is_confirming_ambivalent = $ambivalents->{$solution}{$confirming_argument};

    print "confirming_argument: $confirming_argument ($confirming_stance)\ncounter_argument: $counter_argument ($counter_stance)\n";

    if (!$confirming_stance && $counter_stance) {
      $response = pick($links->{switch}).' '.$say_counter_argument;
      $move = 'counter_argument';
    } elsif (!$counter_stance && $confirming_stance) {
      $response = ($is_confirming_ambivalent ? ($confirming_stance eq '+' ? pick($links->{positive}) : pick($links->{negative})) : pick($links->{yes})).' '.$say_confirming_argument;
      $move = 'confirming_argument';
    } elsif (!$counter_stance && !$confirming_stance) {
      $response = pick($links->{request_expand});
    } else {
      $response = ($is_confirming_ambivalent ? ($confirming_stance eq '+' ? pick($links->{positive}) : pick($links->{negative})) : pick($links->{yes})).' '.$say_confirming_argument.', '.($confirming_stance eq $counter_stance ? pick($links->{and}) : pick($links->{but})).' '.$say_counter_argument;
      $move = 'counter_argument';
    }
  }

  print "move: $move\n";

  if ($move eq 'counter_argument') {
    $response .= ". ".pick($links->{question});
  } elsif ($move eq 'counter_solution') {
    $response .= ". ".pick($links->{question_solution});
  }

  say($response);
}

print "*** CLOSING THE CONVERSATION NOW ***\n";

hear();

say("OK, I think I am confused. Out of the four solutions, which one do you like the best?");

while (1) {
  my $r = hear();
  my @labels = @{classify($r)};
  print "Understood: @labels\n";
  my @solutions = grep { /^solution_/ } @labels;
  my %solutions = map { $_ => 1 } @solutions;
  my $solution = pick(\@solutions);

  if ($solution) {
    say("I agree with you. I think ".$human_names->{$solution}." is a great option.");
    exit;
  }

  say("Sorry, I didn't get it. Which solution do you prefer?");
}
