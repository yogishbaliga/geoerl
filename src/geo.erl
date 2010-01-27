-module (geo).

-define(APPID, "<your appid goes here>" ).

-export ( [woeid/2, woeid/1, woeid_query/1] ).

woeid_query(Query) ->
  case send_request( "/v1/places.q(" ++ Query ++ ")", [{"appid", ?APPID}, {"select", "long"}]) of
    {error, Reason} -> {error, Reason};
    {ok, Body} ->
      {Xml, _} = xmerl_scan:string( erlang:binary_to_list(Body) ),
      parse_places(Xml)
  end.

woeid(Woeid) -> woeid(Woeid, info).

woeid(Woeid, all) ->
  lists:append([[woeid(Woeid, info)], woeid(Woeid, ancestors)]);

woeid(Woeid, info) ->
  case send_request( "/v1/place/" ++ Woeid, [{"appid", ?APPID}]) of
    {ok, Body} -> 
      {Xml, _} = xmerl_scan:string(erlang:binary_to_list(Body)),
      parse_place_element(Xml);
    {error, Reason} -> {error, Reason}
  end;

woeid(Woeid, Type) when Type == ancestors; Type == belongtos; Type == neighbors;
                        Type == siblings; Type == children ->
  case send_request( "/v1/place/" ++ Woeid ++ "/" ++ atom_to_list(Type),  [{"appid", ?APPID}, {"select", "long"}, {"count", "20"}]) of
    {error, Reason} -> {error, Reason};
    {ok, Body} ->
      {Xml, _} = xmerl_scan:string( erlang:binary_to_list(Body) ),
      parse_places(Xml)
  end.


send_request(Uri, Params) ->
  Url = "http://where.yahooapis.com" ++ Uri ++ "?" ++ encode(Params),
  io:format( "Queue: ~p~n", [Url] ),
  case http:request(get, {Url, []}, [], [{body_format, binary}]) of
    {error, Reason} -> {error, Reason};
    {ok, {{_Version, 200, _Reason}, _Headers, Body}} ->
      {ok, Body};
    {ok, {{_Version, _StatusCode, ReasonString}, _Headers, _Body}} -> 
      {error, ReasonString}
  end.

encode(Params) ->
  string:join( lists:map( fun({X, Y}) -> X ++ "=" ++ Y end, Params ), "&" ).

parse_place_element(Element) ->
  {place, lists:flatten(lists:map( fun(F) -> F(Element) end, 
        [fun get_woeid/1, fun get_centroid/1, fun get_place_info/1] ))}.

parse_places(Xml) ->
  case xmerl_xs:select( "place", Xml ) of
    [] -> [];
    Cs when is_list(Cs) -> lists:map( fun parse_place_element/1, Cs )
  end.

get_woeid(Element) ->
  get_xpath(woeid, "woeid", Element).

get_centroid(Element) ->
  case xmerl_xs:select( "centroid", Element ) of
    [] -> [];
    [Cen] ->
      [get_xpath(latitude, "latitude", Cen),
        get_xpath(longitude, "longitude", Cen)]
  end.

get_place_info(Element) ->
  [get_xpath( place_type, "placeTypeName", Element ),
    get_xpath(place_name, "name", Element)].

get_xpath(Atom, Xpath, Element) ->
  case xmerl_xs:select(Xpath, Element) of
    [] -> [];
    [E] -> {Atom, lists:flatten(xmerl_xs:value_of(E))}
  end.

