module UI.Playlists.Alfred exposing (create, select)

import Alfred exposing (..)
import Conditional exposing (ifThenElse)
import Dict
import Dict.Extra as Dict
import List.Extra as List
import Material.Icons.Round as Icons
import Playlists exposing (..)
import Tracks exposing (IdentifiedTrack)
import UI.Types as UI



-- CREATE


create : { collectionMode : Bool } -> List IdentifiedTrack -> List Playlist -> Alfred UI.Msg
create { collectionMode } tracks playlists =
    let
        index =
            makeIndex playlists

        subject =
            ifThenElse collectionMode "collection" "playlist"
    in
    Alfred.create
        { action = createAction collectionMode tracks
        , index = index
        , message =
            if List.length tracks == 1 then
                "Choose or create a " ++ subject ++ " to add this track to."

            else
                "Choose or create a " ++ subject ++ " to add these tracks to."
        , operation = QueryOrMutation
        }


createAction : Bool -> List IdentifiedTrack -> Alfred.Action UI.Msg
createAction collectionMode tracks ctx =
    let
        playlistTracks =
            Tracks.toPlaylistTracks tracks
    in
    case ctx.result of
        Just result ->
            -- Add to playlist
            --
            case Alfred.stringValue result.value of
                Just playlistName ->
                    [ UI.AddTracksToPlaylist
                        { collection = collectionMode
                        , playlistName = playlistName
                        , tracks = playlistTracks
                        }
                    ]

                Nothing ->
                    []

        Nothing ->
            -- Create playlist,
            -- if given a search term.
            --
            case ctx.searchTerm of
                Just searchTerm ->
                    [ UI.AddTracksToPlaylist
                        { collection = collectionMode
                        , playlistName = searchTerm
                        , tracks = playlistTracks
                        }
                    ]

                Nothing ->
                    []



-- SELECT


select : List Playlist -> Alfred UI.Msg
select playlists =
    let
        index =
            makeIndex playlists
    in
    Alfred.create
        { action = selectAction playlists
        , index = index
        , message = "Select a playlist to play tracks from."
        , operation = Query
        }


selectAction : List Playlist -> Alfred.Action UI.Msg
selectAction playlists { result } =
    case Maybe.andThen (\r -> List.find (.name >> Just >> (==) (stringValue r.value)) playlists) result of
        Just playlist ->
            [ UI.SelectPlaylist playlist ]

        Nothing ->
            []



-- ㊙️


makeIndex playlists =
    playlists
        |> Dict.groupBy
            (\p ->
                case p.autoGenerated of
                    Just _ ->
                        "AutoGenerated Directory Playlists"

                    Nothing ->
                        "Your Playlists"
            )
        |> Dict.toList
        |> List.reverse
        |> List.map
            (\( k, v ) ->
                ( k
                , v
                    |> List.map
                        (\playlist ->
                            { icon = Just (Icons.queue_music 16)
                            , title = playlist.name
                            , value = Alfred.StringValue playlist.name
                            }
                        )
                    |> List.sortBy (.title >> String.toLower)
                )
            )
        |> List.map
            (\( k, v ) ->
                { name = Just k, items = v }
            )
