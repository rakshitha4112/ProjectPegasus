:- dynamic wounded_legs/1, hallucinating/1, blind/1, telepathic/1, punished/1, trapped/1, wearing/2, rusty/1, corroded/1.
:- dynamic confused/1, fumbling/1, slippery_fingers/1.
:- dynamic hostile/1.
:- dynamic stepping_on/3.
:- dynamic position/4.
:- dynamic action_count/2.
:- dynamic tameness/2.
:- dynamic carrots/1.
:- dynamic saddles/1.
:- dynamic riding/2. % riding(agent, steed), assert it when mounting, retract it when dismounting/slipping etc.
:- dynamic burdened/1, stressed/1, strained/1, overtaxed/1, overloaded/1.
:- dynamic unencumbered/1.
:- dynamic saddled/1.
% semantics: has(ownerCategory,owner,ownedObjectCat,ownedObject)
:- dynamic has/4.   % It could be recycled for the carrots(X) thing

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
rideable(X) :- is_steed(X), saddled(X), \+ riding(agent,_), \+ hallucinating(agent), \+ wounded_legs(agent), \+ encumbered(agent), \+ (blind(agent), \+ telepathic(agent)), \+ punished(agent)
    , \+ trapped(agent), \+ (wearing(agent, Y), (rusty(Y); corroded(Y))). % I do not intend to implement everything but we can do what we can in the time we have, as a flex

% You will always fail and slip if any of the following apply:[3]
% 
%     You are confused.
%     You are fumbling.
%     You have slippery fingers.
%     Your steed's saddle is cursed.
slippery :- confused(agent); fumbling(agent); slippery_fingers(agent). % WHAT IF THE SADDLE IS CURSED??????

unencumbered(agent) :- \+ burdened(agent), \+ stressed(agent), \+ strained(agent), \+ overtaxed(agent), \+ overloaded(agent).
encumbered(agent) :- stressed(agent); strained(agent); overtaxed(agent); overloaded(agent). %no burdened?

%%% GENERAL SUBTASKS feel free to add other conditions or comments to suggest them

action(pick) :-
    stepping_on(agent,ObjClass,Obj),
    is_pickable(ObjClass),
    (
        ( %the bject is a saddle
            (Obj == saddle),
            (
                (max_tameness(MT), tameness(Steed,T), is_steed(Steed), carrots(X), MT - T > X); % can start mounting procedure
                starvationRiding % there is nothing we can do to tame the pony
            )
        );
        ( %the object is not a saddle
            \+ (Obj == saddle)
        )
    ).

action(getCarrot) :- 
    carrots(X),is_steed(Steed),(
        (X == 0, \+ stepping_on(agent,_,carrot), position(comestible,carrot,_,_), 
        hostile(Steed));
        (max_tameness(MT), tameness(Steed,T), MT - T > X, 
        \+ hostile(Steed))
    ).    % Can be stopped if danger (to implement)


action(getSaddle) :- 
    saddles(X), X == 0, \+ stepping_on(agent,_,saddle), position(applicable,saddle,_,_),  
    (
        ( 
            tameness(Steed,MT),
            max_tameness(MT),
            is_steed(Steed)
        );
        (
            starvationRiding
        )
    ).


% The idea is: if the pony isn't in sight the agent can hoard carrots in the meantime
action(feedSteed) :- 
    is_steed(Steed), carrots(X), position(steed,Steed,RS,CS),position(agent,agent,RA,CA),
    (
        (
            hostile(Steed), X > 0  % if the pony is far away, but there are enemies then fight may be worthwile
        );
        (
            \+hostile(Steed), % consider enemies if they are close
            (
                is_close(RA,CA,RS,CS);  %not hostile but close
                (tameness(Steed,T), max_tameness(MT), X >= MT - T) %max tameanes can be reached
            )
        )
    ).

action(applySaddle) :- 
    saddles(X), X > 0,
    is_steed(Steed),
    \+ saddled(Steed),
    (
        (max_tameness(MT),tameness(Steed,MT));
        (starvationRiding)
    ).

action(rideSteed) :- 
    rideable(Steed), 
    \+ hostile(Steed),
    (
        (max_tameness(MT),tameness(Steed,T), T >= MT);
        (starvationRiding)
    ).


%we need to explore if the pony is/can_be tamed but we dont't know where it is
%we need to explore if the pony is not tamed and we don't have carrots
action(explore) :- 
    (tameness(Steed, T), max_tameness(MT), carrots(X), is_steed(Steed)),
    (
        (X >= MT - T, \+ position(_, Steed, _, _)); 
        (X < MT - T, \+ position(comestible, carrot, _, _))
    ).

%%% INTERRUPT CONDITIONS
interrupt(getCarrot) :- 
    carrots(X), X > 0; 
    stepping_on(agent,comestible,carrot); 
    \+ position(comestible,carrot,_,_); 
    (is_steed(Steed), \+ hostile(Steed)).

interrupt(getSaddle) :- 
    saddles(X), X > 0; 
    stepping_on(agent,saddle,_); 
    \+ position(applicable,saddle,_,_).

interrupt(pacifySteed) :-
    \+ action(pacifySteed).

interrupt(feedSteed) :- 
    (carrots(X), X == 0); 
    (tameness(Steed, T), is_steed(Steed), max_tameness(MT), T == MT).

interrupt(rideSteed) :- 
    (is_steed(Steed), \+ rideable(Steed)); 
    (hostile(Steed), is_steed(Steed)); 
    ((carrots(X), X > 0); position(comestible,carrot,_,_), (tameness(Steed, T), is_steed(Steed), max_tameness(MT), T < MT)).

interrupt(hoardCarrots) :- 
    (carrots(X), tameness(Steed, T), is_steed(Steed), max_tameness(MT), T+X >= MT);
    (hostile(Steed), is_steed(Steed)).

interrupt(explore) :- \+ action(explore).

% We make use of hostile(steed) predicate. But when is a steed hostile?
% Very naively, I'd say that
% we infer it from the screen description. If the steed is peaceful, it says "tame/peaceful pony/horse/etc"
% hostile(Steed) :- is_steed(Steed), tameness(Steed, T), T < 2. In the 1% chance the steed spawns peaceful, it will nevertheless start with tameness = 1

% We need to check this if we are to throw carrots at a horse.
is_aligned(R1,C1,R2,C2) :- R1 == R2; C1 == C2; ((R1 is R2+X;R1 is R2-X), (C1 is C2+X;C1 is C2-X)).

% Directionality and space conditions, taken from handson2
% test the different condition for closeness
% two objects are close if they are at 1 cell distance, including diagonals
is_close(R1,C1,R2,C2) :- R1 == R2, (C1 is C2+1; C1 is C2-1).
is_close(R1,C1,R2,C2) :- C1 == C2, (R1 is R2+1; R1 is R2-1).
is_close(R1,C1,R2,C2) :- (R1 is R2+1; R1 is R2-1), (C1 is C2+1; C1 is C2-1).

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
unsafe_position(_,_) :- fail.
% \+ means "the proposition is not entailed by KB". Sort of a not, but more general
safe_position(R,C) :- \+ unsafe_position(R,C).

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

% we need to pick a carrot if we are stepping on it. 
is_pickable(comestible).
is_pickable(applicable).
is_pickable(weapon).

% what is a steed? it's a horse-like creature. "destriero" in italian.
is_steed(steed).
is_steed(pony).
is_steed(horse).
is_steed(warhorse).
carrots(0).
saddles(0).
action_count(feed, 0).
% tameness is 1 at the beginning of the game
%tameness(steed, 1).
tameness(pony, 1).
tameness(horse, 1).
tameness(warhorse, 1).
max_tameness(20).

%here some extreme conditions
% if we have explored the map 3 times and the pony is not tamed
% we are should accept the fact that we cannot tame it (maybe he stoole some carrots)
% so we should try to ride it anyway
fullyExplored(0).
starvationRiding :- fullyExplored(X), X > 2, \+ position(comestible, carrot, _, _), carrots(0).

%add wait conditions if agent has saddle and steed is tamed
%also enemies close to the pony (save the pony Ryan)
%add condition fullyExplored(X) wher X is the number of times the agent has explored the map