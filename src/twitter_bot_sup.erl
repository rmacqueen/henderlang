%%%-------------------------------------------------------------------
%% @doc twitter_bot top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(twitter_bot_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

-define(CONTENT_TYPE, "application/x-www-form-urlencoded").
-define(CONSUMER_KEY, os:getenv("CONSUMER_KEY")).
-define(CONSUMER_SECRET, os:getenv("CONSUMER_SECRET")).
-define(ACCESS_TOKEN, os:getenv("ACCESS_TOKEN")).
-define(ACCESS_SECRET, os:getenv("ACCESS_SECRET")).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    stream(),
    {ok, { {one_for_all, 0, 1}, []} }.

%%====================================================================
%% Internal functions
%%====================================================================


stream() ->
    Url = "https://stream.twitter.com/1.1/statuses/filter.json",
    Method = "POST",
    Params = [
              {"track", "comprised"}
             ],

    Headers = [auth_header(Method, Url, Params)],
    Options = [async, {recv_timeout, 600000}],
    io:format("Starting stream...~n"),
    {ok, ClientRef} = hackney:post(Url, Headers, {form, Params}, Options),
    loop_fun(ClientRef, ""),
    stream().


loop_fun (Ref, OldChunk) ->
    receive
        {hackney_response, Ref, {status, 420, Reason}} ->
            io:format("TOO MANY REQUESTS!");
        {hackney_response, Ref, {status, StatusInt, Reason}} ->
            io:format("got status: ~p with reason ~p~n", [StatusInt,
                                                          Reason]),
            loop_fun(Ref, "");
        {hackney_response, Ref, {headers, Headers}} ->
            loop_fun(Ref, "");
        {hackney_response, Ref, done} ->
            ok;
        {hackney_response, Ref, {error, {closed, timeout}}} ->
            io:format("CONNECTION TIMED OUT");
        {hackney_response, Ref, Bin} ->
            Combinedchunk = OldChunk ++ binary_to_list(Bin),

            case lists:suffix("\n", Combinedchunk) of
                true ->
                    Stripped = re:replace(Combinedchunk, "(^\\s+)|(\\s+$)", "", [global,{return,list}]),
                    case length(Stripped) of
                        0 ->
                            loop_fun(Ref, "");
                        Num ->    
                            Obj = jsx:decode(list_to_binary(Combinedchunk), [return_maps]),
                            case maps:is_key(<<"text">>, Obj) andalso maps:is_key(<<"retweeted_status">>, Obj) /= true of
                                true ->
                                    io:format("Got a hit: ~s~n", [binary_to_list(maps:get(<<"text">>, Obj))]),

                                    Match = re:split(maps:get(<<"text">>, Obj), "(\\bbe\\b|\\bis\\b|\\bare\\b|\\bwas\\b)\s*comprised\s*\\bof\\b", [{return, list}]),

                                    Tweet_User = maps:get(<<"user">>, Obj),
                                    Username = binary_to_list(maps:get(<<"screen_name">>, Tweet_User)),

                                    Tweet_Id = maps:get(<<"id">>, Obj),
                                    io:format("Match ~s~n", [Match]),
                                    case length(Match) of
                                        3 ->
                                            [Pre, Tobe, Post] = Match,
                                            PreArr = re:split(Pre, " ", [{return, list}]),
                                            PreArrShort = lists:nthtail(length(PreArr) - 4, PreArr),
                                            NewPre = string:join(PreArrShort, " "),
                                            PostArr = re:split(Post, " ", [{return, list}]),
                                            PostArrShort = lists:sublist(PostArr, 3),
                                            NewPost = string:join(PostArrShort, " "),
                                            Result = "Correction: " ++ NewPre ++ Tobe ++ " composed of" ++ NewPost ++ " " ++ "https://en.wikipedia.org/wiki/User:Giraffedata/comprised_of",
                                            io:format("Result: ~s~n", [Result]),

                                            submit_reply(Tweet_Id, Username, Result);
                                        Not3 ->
                                            io:format("Did not get a match~n")
                                    end,

                                    loop_fun(Ref, "");
                                false ->
                                    loop_fun(Ref, "")
                            end
                    end;
                false ->
                    loop_fun(Ref, Combinedchunk)
            end;
        Else ->
            ok
    end.

auth_header(Method, Url, Params) ->
    Consumer = {?CONSUMER_KEY, ?CONSUMER_SECRET, hmac_sha1},
    SignedParams = oauth:sign(Method, Url, Params, Consumer, ?ACCESS_TOKEN, ?ACCESS_SECRET),
    SignedParams1 = lists:filter(fun ({K, _}) -> string:str(K, "oauth_") == 1 end, SignedParams),
    SignedParams2 = lists:sort(SignedParams1),
    BinaryParams = [ {list_to_binary(K), hackney_url:urlencode(list_to_binary(V))} || {K, V} <- SignedParams2 ],
    OAuth = hackney_bstr:join([ <<K/binary, "=", $\", V/binary, $\">> || {K, V} <- BinaryParams ], ","),
                                  {<<"Authorization">>, <<"OAuth ", OAuth/binary>>}.


submit_reply(Tweet_Id, Username, Reply) ->
    io:format("Submitting reply to: ~p~n", [Username]),
    Urlbase = "https://api.twitter.com/1.1/statuses/update.json",
    Url = "https://api.twitter.com/1.1/statuses/update.json",

    Consumer = {?CONSUMER_KEY, ?CONSUMER_SECRET, hmac_sha1},

    TweetReply = "@" ++ Username ++ " " ++ Reply,

    Tweet_Id_str = integer_to_list(Tweet_Id),
    TweetParams = [{"status", TweetReply}, {"in_reply_to_status_id", Tweet_Id_str}],
    SignedParams = oauth:sign("POST", Urlbase, TweetParams, Consumer, ?ACCESS_TOKEN, ?ACCESS_SECRET),

    Header = [oauth:header(SignedParams), {"Host", "api.twitter.com"}, {"User-Agent", "Twerl"}],
    Body = oauth:uri_params_encode(TweetParams),

    R = httpc:request(post, {Url, Header, ?CONTENT_TYPE, Body}, [], []),

    {ok, {{"HTTP/1.1",ReturnCode, State}, Head, ResponseBody}} = R,
    io:format("Response Body~p~n", [ResponseBody]).
