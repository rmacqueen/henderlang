%%%-------------------------------------------------------------------
%% @doc twitter_bot public API
%% @end
%%%-------------------------------------------------------------------

-module(twitter_bot_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    twitter_bot_sup:start_link().


%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================