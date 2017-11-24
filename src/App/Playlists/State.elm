module Playlists.State exposing (..)

import List.Extra as List
import Playlists.Types exposing (..)
import Response.Ext exposing (do)
import Routing.Types
import Types as TopLevel
import Utils exposing (displayError)


-- 💧


initialModel : Model
initialModel =
    { collection = []
    , lastModifiedPlaylist = Nothing
    , newPlaylist = { autoGenerated = False, name = "", tracks = [] }
    }



-- 🔥


update : Msg -> Model -> ( Model, Cmd TopLevel.Msg )
update msg model =
    case msg of
        SetCollection col ->
            (!) { model | collection = col, lastModifiedPlaylist = Nothing } []

        ------------------------------------
        -- Addition
        ------------------------------------
        AddToPlaylist name tracks ->
            let
                newCollection =
                    List.updateIf
                        (.name >> (==) name)
                        (\p -> { p | tracks = List.append p.tracks tracks })
                        model.collection
            in
                (!)
                    { model | collection = newCollection, lastModifiedPlaylist = Just name }
                    [ do TopLevel.DebounceStoreUserData ]

        ------------------------------------
        -- Creation
        ------------------------------------
        CreateFromForm ->
            let
                newCollection =
                    model.newPlaylist :: model.collection

                newName =
                    model.newPlaylist.name

                existingPlaylist =
                    List.find
                        (\p -> p.autoGenerated == False && p.name == newName)
                        model.collection
            in
                case existingPlaylist of
                    Just _ ->
                        (!)
                            model
                            [ displayError "A playlist with that name already exists" ]

                    Nothing ->
                        (!)
                            { model
                                | collection = newCollection
                                , lastModifiedPlaylist = Just newName
                            }
                            [ do TopLevel.DebounceStoreUserData
                            , Index
                                |> Routing.Types.Playlists
                                |> Routing.Types.GoToPage
                                |> TopLevel.RoutingMsg
                                |> do
                            ]

        CreateWithTracks name tracks ->
            let
                newPlaylist =
                    { autoGenerated = False
                    , name = name
                    , tracks = tracks
                    }

                newCollection =
                    newPlaylist :: model.collection
            in
                (!)
                    { model | collection = newCollection, lastModifiedPlaylist = Just name }
                    [ do TopLevel.DebounceStoreUserData ]

        SetNewPlaylistName name ->
            let
                newPlaylist =
                    model.newPlaylist
            in
                (!)
                    { model
                        | newPlaylist =
                            { newPlaylist | name = String.trim name }
                    }
                    []

        ------------------------------------
        -- Removal
        ------------------------------------
        Remove name ->
            let
                newCollection =
                    List.filterNot
                        (\p -> p.autoGenerated == False && p.name == name)
                        model.collection

                lastMod =
                    if model.lastModifiedPlaylist == Just name then
                        Nothing
                    else
                        model.lastModifiedPlaylist
            in
                (!)
                    { model | collection = newCollection, lastModifiedPlaylist = lastMod }
                    [ do TopLevel.DebounceStoreUserData ]

        RemoveTrackByIndex playlistName trackIndex ->
            let
                newCollection =
                    List.updateIf
                        (.name >> (==) playlistName)
                        (\p -> { p | tracks = List.removeAt trackIndex p.tracks })
                        model.collection

                lastMod =
                    Just playlistName
            in
                (!)
                    { model | collection = newCollection, lastModifiedPlaylist = lastMod }
                    [ do TopLevel.CheckSelectedPlaylist
                    , do TopLevel.DebounceStoreUserData
                    ]



-- Lenses
