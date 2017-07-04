Henderlang
=====

A prescriptive grammar twitter bot written in Erlang.

Although writers will occasionally use it, 'comprised of' should be avoided, since the construction introduces unnecessary inconsistency and imprecision into the English language. 'To comprise' means to include or to be composed of several things. It is therefore illogical that its grammatical opposite, 'to be comprised of', could mean the same thing. For a more complete argument against its usage, please see [this wikipedia page](https://en.wikipedia.org/wiki/User:Giraffedata/comprised_of).

This bot listen's to a stream of tweets and detects those which contain some variation of the phrase 'is comprised of.' It will then tweet a reply to the offender, informing them of their mistake along with a suggestion for how to fix it.

Build
-----

To build, you'll need to install both erlang and rebar3. Then you can execute:

    rebar3 release
    
to compile and build and then

    rebar3 shell
    
to run. Note that you will have to set the following environment variables before running in order to have access to the Twitter API: CONSUMER_KEY, CONSUMER_SECRET, ACCESS_TOKEN, ACCESS_SECRET.
