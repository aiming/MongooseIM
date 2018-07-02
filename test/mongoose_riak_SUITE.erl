-module(mongoose_riak_SUITE).
-author("bartlomiej.gorny@erlang-solutions.com").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all]).
all() ->
    [{group, crud}].

groups() ->
    [{crud, [], crud_tests()}].

crud_tests() ->
    [simple_crud].


init_per_testcase(_, Config) ->
    case start_riak_connector() of
        ok -> Config;
        not_available -> {skip, riak_server_not_available}
    end.

end_per_testcase(_, Config) ->
    stop_riak_connector(),
    Config.

simple_crud(_) ->
    Obj = riakc_obj:new(<<"abucket">>, <<"akey">>, <<"avalue">>),
    mongoose_riak:put(Obj),
    {ok, Res} = mongoose_riak:get(<<"abucket">>, <<"akey">>),
    ?assertEqual(<<"avalue">>, riakc_obj:get_value(Res)),
    Obj1 = riakc_obj:new(<<"abucket">>, <<"akey">>, <<"anothervalue">>),
    mongoose_riak:put(Obj1),
    {ok, Res1} = mongoose_riak:get(<<"abucket">>, <<"akey">>),
    ?assertEqual(<<"anothervalue">>, riakc_obj:get_value(Res1)),
    ok = mongoose_riak:delete(<<"abucket">>, <<"akey">>),
    {error, notfound} = mongoose_riak:get(<<"abucket">>, <<"akey">>),
    ok.

start_riak_connector() ->
    meck:new(ejabberd_config, []),
    meck:expect(ejabberd_config, get_local_option, fun(riak_server) -> riak_config() end),
    mongoose_riak:start(),
    case mongoose_riak:list_buckets(<<"default">>) of
        {ok, _} -> ok;
        {error, disconnected} -> not_available
    end.

stop_riak_connector() ->
    mongoose_riak:stop(),
    meck:unload(ejabberd_config).

riak_config() ->
    [{address, "localhost"},
     {port, 8087}].

