:- dynamic encumbered/1, wounded_legs/1, hallucinating/1, riding/1, blind/1, telepathic/1, punished/1, trapped/1, wearing/2, rusty/1, corroded/1.
:- dynamic confused/1, fumbling/1, slippery_fingers/1.
:- dynamic hostile/1.
:- dynamic stepping_on/3.
:- dynamic position/4.
:- dynamic action_count/2.
:- dynamic tameness/2.
:- dynamic carrots/1.
:- dynamic saddles/1.

% To translate into Prolog:
% Chance of succeeding a mounting action is: 5 * (exp level + steed tameness)
% cannot attempt to mount a steed if any of the following conditions apply:
% 
%     You are already riding.
%     You are hallucinating.
%     Your have wounded legs.
%     Your encumbrance is stressed or worse.
%     You are blind and not telepathic.
%     You are punished.
%     You or your steed are trapped.
%     You are levitating and cannot come down at will.
%     You are wearing rusty or corroded body armor.
rideable(X) :- \+ riding(agent), \+ hallucinating(agent), \+ wounded_legs(agent), \+ encumbered(agent), \+ (blind(agent), \+ telepathic(agent)), \+ punished(agent)
    , \+ trapped(agent), \+ (wearing(agent, Y), (rusty(Y); corroded(Y))). % I do not intend to implement everything but we can do what we can in the time we have, as a flex

% You will always fail and slip if any of the following apply:[3]
% 
%     You are confused.
%     You are fumbling.
%     You have slippery fingers.
%     Your steed's saddle is cursed.
slippery :- confused(agent); fumbling(agent); slippery_fingers(agent). % WHAT IF THE SADDLE IS CURSED?????? 

%TODO: it is currently unused
carrots(0).
saddles(0).
action(throw) :- carrots(X), X > 0, is_aligned(AR,AC,SR,SC). % "A" coordinates are the agent's while "S" coordinates are the steed's

max_tameness(20).

%%% GENERAL SUBTASKS feel free to add other conditions or comments to suggest them
action(getCarrot) :- carrots(X), X == 0, \+ stepping_on(agent,carrot,_), position(carrot,_,_,_); hostile(steed).
action(getSaddle) :- saddles(X), X == 0, \+ stepping_on(agent,saddle,_), position(saddle,_,_,_).
action(pacifySteed) :- hostile(steed), carrots(X), X > 0.
action(feedSteed) :- carrots(X), X > 0, \+ hostile(steed), tameness(steed, T), max_tameness(MT), T =< MT.
action(rideSteed) :- rideable(steed), \+ hostile(steed), carrots(X), X == 0, \+ position(carrot,_,_,_).


% We will need to eventually pick the carrot
action(pick) :- 
    stepping_on(agent,ObjClass,_),
    is_pickable(ObjClass). 

% We need to count how many times we fed the steed to calculate its tameness.
action_count(feed, 0).
tameness(steed, 1).

increment_action_count(A) :- retract(action_count(A, N)),  % remove the old value. At initialization the we assert action_count(A, 0) for A = feed
                             NewN is N+1, % increment the value
                             assert(action_count(A, NewN)). % assert the new value

increment_tameness(X) :- retract(tameness(X, N)),  % remove the old value. At initialization we assert tameness(X, 1) for X = steed
                         NewN is N+1, % increment the value
                         assert(tameness(X, NewN)). % assert the new value

% Decreased when using the ride action
decrease_tameness(X) :- retract(tameness(X, N)),  % remove the old value.
                         NewN is N-1, % increment the value
                         assert(tameness(X, NewN)). % assert the new value

feed(X) :- increment_action_count(feed), increment_tameness(X).

% We need to check this if we are to throw carrots at a horse.
is_aligned(R1,C1,R2,C2) :- R1 == R2; C1 == C2; ((R1 is R2+X;R1 is R2-X), (C1 is C2+X;C1 is C2-X)).

% Directionality and space conditions, taken from handson2
% test the different condition for closeness
% two objects are close if they are at 1 cell distance, including diagonals
is_close(R1,C1,R2,C2) :- R1 == R2, (C1 is C2+1; C1 is C2-1).
is_close(R1,C1,R2,C2) :- C1 == C2, (R1 is R2+1; R1 is R2-1).
is_close(R1,C1,R2,C2) :- (R1 is R2+1; R1 is R2-1), (C1 is C2+1; C1 is C2-1).

% compute the direction given the starting point and the target position
% check if the direction leads to a safe position
% D = temporary direction - may be unsafe
% Direction = the definitive direction 
% in the future we're going to need some more complex algorithm to search a path since rooms will not always be rectangular.
% suggestion: implement those algorithms in Python 
next_step(R1,C1,R2,C2, D) :-
    ( R1 == R2 -> ( C1 > C2 -> D = west; D = east );
    ( C1 == C2 -> ( R1 > R2 -> D = north; D = south);
    ( R1 > R2 ->
        ( C1 > C2 -> D = northwest; D = northeast );
        ( C1 > C2 -> D = southwest; D = southeast )
    ))).
    % safe_direction(R1, C1, D,Direction).

% check if the selected direction is safe
safe_direction(R, C, D,Direction) :- resulting_position(R, C, NewR, NewC, D),
                                      ( safe_position(NewR, NewC) ->Direction = D;
                                      % else, get a new close direction
                                      % and check its safety
                                      close_direction(D, ND), safe_direction(R, C, ND,Direction)
                                      ).

% a square is unsafe if there is a trap or an enemy
unsafe_position(R, C) :- position(trap,_, R, C).
unsafe_position(R, C) :- position(enemy,_, R, C).
unsafe_position(R,C) :- 
    position(enemy,_, ER, EC), 
    is_close(ER, EC, R, C).

%%%% known facts %%%%
opposite(north, south).
opposite(south, north).
opposite(east, west).
opposite(west, east).
opposite(northeast, southwest).
opposite(southwest, northeast).
opposite(northwest, southeast).
opposite(southeast, northwest).

resulting_position(R, C, NewR, NewC, north) :-
    NewR is R-1, NewC = C.
resulting_position(R, C, NewR, NewC, south) :-
    NewR is R+1, NewC = C.
resulting_position(R, C, NewR, NewC, west) :-
    NewR = R, NewC is C-1.
resulting_position(R, C, NewR, NewC, east) :-
    NewR = R, NewC is C+1.
resulting_position(R, C, NewR, NewC, northeast) :-
    NewR is R-1, NewC is C+1.
resulting_position(R, C, NewR, NewC, northwest) :-
    NewR is R-1, NewC is C-1.
resulting_position(R, C, NewR, NewC, southeast) :-
    NewR is R+1, NewC is C+1.
resulting_position(R, C, NewR, NewC, southwest) :-
    NewR is R+1, NewC is C-1.

close_direction(north, northeast).
close_direction(northeast, east).
close_direction(east, southeast).
close_direction(southeast, south).
close_direction(south, southwest).
close_direction(southwest, west).
close_direction(west, northwest).
close_direction(northwest, north).

unsafe_position(_,_) :- fail.
% \+ means "the proposition is not entailed by KB". Sort of a not, but more general
safe_position(R,C) :- \+ unsafe_position(R,C).

% we need to pick a carrot if we are stepping on it. 
is_pickable(carrots).