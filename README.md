# README

## Problem: Conference Track Management

You are planning a big programming conference and have received many proposals
which have passed the initial screen process but you're having trouble fitting
them into the time constraints of the day -- there are so many possibilities!
So you write a program to do it for you.

 * The conference has multiple tracks each of which has a morning and afternoon session.
 * Each session contains multiple talks.
 * Morning sessions begin at 9am and must finish by 12 noon, for lunch.
 * Afternoon sessions begin at 1pm and must finish in time for the networking event.
 * The networking event can start no earlier than 4:00 and no later than 5:00.
 * No talk title has numbers in it.
 * All talk lengths are either in minutes (not hours) or lightning (5 minutes).
 * Presenters will be very punctual; there needs to be no gap between sessions.

Note that depending on how you choose to complete this problem, your solution
may give a different ordering or combination of talks into tracks.
This is acceptable; you don’t need to exactly duplicate the sample output given
here.

### Test input:

    Evoluindo uma aplicação com uso do Elasticsearch 45min
    Vagrant, LXC and Docker: Know the differences 30min
    Ruby on Rails 45min
    How to test my Javascript code? 45min
    The developer choices lightning
    Not-Entreprise Message Bus 60min
    Ruby + Linux Pipe + Graph Database + Hard Work 45min
    Rails and Javascript - Do it right! 30min
    Sit Down and Write 30min
    Pair Programming vs Noise 45min
    Rails Magic 60min
    Ruby on Rails: Why We Should Move On 60min
    Clojure Ate Scala (on my project) 45min
    Programming in the Boondocks of Seattle 30min
    Ruby vs. Clojure for Back-End Development 30min
    Ruby on Rails Legacy App Maintenance 60min
    A World Without HackerNews 30min
    User Interface CSS in Rails Apps 30min
    Writing Fast Tests Against Enterprise Rails 60min

### Test Output

#### TRACK 1

    - MORNING SESSION
    09:00 Evoluindo uma aplicação com uso do Elasticsearch 45min
    09:45 Vagrant, LXC and Docker: Know the differences 30min
    10:15 Ruby on Rails 45min
    11:00 How to test my Javascript code? 45min
    11:45 The developer choices lightning
    12:00 Lunch
    - AFTERNOON SESSION
    13:00 Not-Entreprise Message Bus 60min
    14:00 Ruby + Linux Pipe + Graph Database + Hard Work 45min
    14:45 Rails and Javascript - Do it right! 30min
    15:15 Sit Down and Write 30min
    15:45 Pair Programming vs Noise 45min
    16:30 Programming in the Boondocks of Seattle 30min
    17:00 Networking Event
    ===============================
    TRACK 2
    - MORNING SESSION
    09:00 Rails Magic 60min
    10:00 Ruby on Rails: Why We Should Move On 60min
    11:00 Clojure Ate Scala (on my project) 45min
    12:00 Lunch
    - AFTERNOON SESSION
    13:00 Ruby vs. Clojure for Back-End Development 30min
    13:30 Ruby on Rails Legacy App Maintenance 60min
    14:30 A World Without HackerNews 30min
    15:00 User Interface CSS in Rails Apps 30min
    15:30 Writing Fast Tests Against Enterprise Rails 60min
    16:30 Networking Event
    ===============================
