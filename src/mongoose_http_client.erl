%%==============================================================================
%% Copyright 2016 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================
%%%-------------------------------------------------------------------
%%% @doc
%% options and defaults:
%% [
%%     {selection_strategy, available_worker},
%%     {server, (required)},
%%     {path_prefix, ""},
%%     {request_timeout, 2000},
%%     {pool_timeout, 5000}, % waiting for worker - not for all selection strategies
%%     {pool_size, 20},
%%     {http_opts, []}, % passed to fusco
%%     {pool_opts, []} % extra options for worker_pool
%% ]
%%%
%%% @end
%%% Created : 26. Jun 2018 13:07
%%%-------------------------------------------------------------------
-module(mongoose_http_client).
-author("bartlomiej.gorny@erlang-solutions.com").
-include("mongoose.hrl").

%% API
-export([start/0, stop/0, start_pool/2, stop_pool/1, get/3, post/4]).
-export([get_pool/1]). % for backward compatibility

%% Exported for testing
-export([start/1]).

-spec start() -> ok.
start() ->
    mongoose_wpool:setup_env(),
    case ejabberd_config:get_local_option(http_connections) of
        undefined -> ok;
        Opts -> start(Opts)
    end.

-spec stop() -> any().
stop() ->
    case ejabberd_config:get_local_option(http_connections) of
        undefined -> ok;
        Opts -> lists:map(fun({Name, _}) -> stop_pool(Name) end, Opts)
    end.

-spec start_pool(atom(), list()) -> ok | {error, already_started}.
start_pool(Name, Opts) ->
    PoolName = pool_name(new, Name),
    case whereis(PoolName) of
        undefined ->
            mongoose_wpool:setup_env(),
            do_start_pool(PoolName, Opts),
            ok;
        _ -> {error, already_started}
    end.

-spec stop_pool(atom()) -> ok.
stop_pool(Name) ->
    wpool:stop_sup_pool(pool_name(Name)),
    mongoose_wpool:delete_pool_settings(pool_name(Name)),
    ok.

-spec get(atom(), binary(), list()) ->
    {ok, {binary(), binary()}} | {error, any()}.
get(Pool, Path, Headers) ->
    make_request(Pool, Path, <<"GET">>, Headers, <<>>).

-spec post(atom(), binary(), list(), binary()) ->
    {ok, {binary(), binary()}} | {error, any()}.
post(Pool, Path, Headers, Query) ->
    make_request(Pool, Path, <<"POST">>, Headers, Query).

get_pool(PoolName) -> PoolName.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


start(Opts) ->
    [start_pool(Name, PoolOpts) || {Name, PoolOpts} <- Opts],
    ok.

do_start_pool(PoolName, Opts) ->
    SelectionStrategy = gen_mod:get_opt(selection_strategy, Opts, available_worker),
    PathPrefix = list_to_binary(gen_mod:get_opt(path_prefix, Opts, "/")),
    RequestTimeout = gen_mod:get_opt(request_timeout, Opts, 2000),
    PoolTimeout = gen_mod:get_opt(pool_timeout, Opts, 5000),
    PoolSettings = #mongoose_worker_pool{selection_strategy = SelectionStrategy,
                                         extra = PathPrefix,
                                         request_timeout = RequestTimeout,
                                         pool_timeout = PoolTimeout},
    mongoose_wpool:save_pool_settings(PoolName, PoolSettings),
    PoolSize = gen_mod:get_opt(pool_size, Opts, 20),
    Server = gen_mod:get_opt(server, Opts),
    HttpOpts = gen_mod:get_opt(http_opts, Opts, []),
    PoolOpts = [{workers, PoolSize}, {worker, {fusco, {Server, HttpOpts}}}
                | gen_mod:get_opt(pool_opts, Opts, [])],
    wpool:start_sup_pool(PoolName, PoolOpts).

make_request(Pool, Path, Method, Headers, Query) ->
    PoolName = pool_name(Pool),
    case mongoose_wpool:get_pool_settings(PoolName) of
        undefined ->
            {error, pool_not_started};
        PoolOpts ->
            make_request(PoolName, PoolOpts, Path, Method, Headers, Query)
    end.

make_request(PoolName, PoolOpts, Path, Method, Headers, Query) ->
    #mongoose_worker_pool{extra = PathPrefix,
                          request_timeout = RequestTimeout,
                          pool_timeout = PoolTimeout,
                          selection_strategy = SelectionStrategy} = PoolOpts,
    FullPath = <<PathPrefix/binary, Path/binary>>,
    Req = {request, FullPath, Method, Headers, Query, 2, RequestTimeout},
    try
        case wpool:call(PoolName, Req, SelectionStrategy, PoolTimeout) of
            {ok, {{Code, _Reason}, _RespHeaders, RespBody, _, _}} ->
                {ok, {Code, RespBody}};
            {error, timeout} ->
                {error, request_timeout};
            {'EXIT', Reason} ->
                {error, {'EXIT', Reason}};
            {error, Reason} ->
                {error, Reason}
        end
    catch
        exit:timeout ->
            {error, pool_timeout};
        exit:no_workers ->
            {error, pool_down};
        Type:Reason ->
            {error, {Type, Reason}}
    end.

pool_name(PoolName) ->
    list_to_existing_atom("mongoose_http_client_pool_" ++ atom_to_list(PoolName)).

pool_name(new, PoolName) ->
    list_to_atom("mongoose_http_client_pool_" ++ atom_to_list(PoolName)).
