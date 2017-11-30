module Tracks.Collection.Internal.Identify exposing (identify)

import List.Ext as List
import List.Extra as List exposing ((!!))
import Playlists.Types exposing (..)
import Playlists.Utils exposing (..)
import Tracks.Favourites as Favourites
import Tracks.Sorting as Sorting
import Tracks.Types exposing (..)


-- 🍯


identify : Parcel -> Parcel
identify parcel =
    parcel
        |> Tuple.mapFirst .selectedPlaylist
        |> Tuple.first
        |> Maybe.map (playlistIdentify parcel)
        |> Maybe.withDefault (defaultIdentify parcel)



-- Identifying


defaultIdentify : Parcel -> Parcel
defaultIdentify ( model, collection ) =
    let
        ( identifiedUnsorted, missingFavourites ) =
            collection.untouched
                |> List.filter
                    (\track -> List.member track.sourceId model.enabledSourceIds)
                |> List.foldr
                    (defaultIdentifier model.favourites model.activeIdentifiedTrack Nothing)
                    ( [], model.favourites )
    in
        identifiedUnsorted
            |> List.append (List.map makeMissingFavouriteTrack missingFavourites)
            |> Sorting.sort model.sortBy model.sortDirection
            |> (\x -> { collection | identified = x })
            |> (\x -> (,) model x)


playlistIdentify : Parcel -> Playlist -> Parcel
playlistIdentify ( model, collection ) selectedPlaylist =
    let
        playlistTracks =
            identifyPlaylistTracks selectedPlaylist

        ( identifiedUnsorted, missingFavourites, missingPlaylistTracks ) =
            collection.untouched
                |> List.filter
                    (\track -> List.member track.sourceId model.enabledSourceIds)
                |> List.foldr
                    (playlistIdentifier model.favourites model.activeIdentifiedTrack)
                    ( [], model.favourites, playlistTracks )

        sortingFunction =
            if selectedPlaylist.autoGenerated then
                Sorting.sort model.sortBy model.sortDirection
            else
                Sorting.sort PlaylistIndex Asc
    in
        identifiedUnsorted
            |> List.append (List.map makeMissingFavouriteTrack missingFavourites)
            |> sortingFunction
            |> (\x -> { collection | identified = x })
            |> (\x -> (,) model x)



-- Identifier / Default


defaultIdentifier :
    List Favourite
    -> Maybe IdentifiedTrack
    -> Maybe Int
    -> Track
    -> ( List IdentifiedTrack, List Favourite )
    -> ( List IdentifiedTrack, List Favourite )
defaultIdentifier favourites nowPlaying maybeIndexInPlaylist track ( acc, missingFavourites ) =
    let
        isNowPlaying =
            case nowPlaying of
                Just ( identifiers, activeTrack ) ->
                    case maybeIndexInPlaylist of
                        Just idx ->
                            track.id == activeTrack.id && Just idx == identifiers.indexInPlaylist

                        Nothing ->
                            track.id == activeTrack.id

                Nothing ->
                    False

        identifiedTrack =
            (,)
                { indexInPlaylist = maybeIndexInPlaylist
                , isFavourite = False
                , isMissing = False
                , isNowPlaying = isNowPlaying
                }
                track
    in
        case List.any (isFavourite track) favourites of
            --
            -- A favourite
            --
            True ->
                ( identifiedTrack
                    |> Tuple.mapFirst (\i -> { i | isFavourite = True })
                    |> List.addInFront acc
                , missingFavourites
                    |> List.filterNot (isFavourite track)
                )

            --
            -- Not a favourite
            --
            False ->
                ( identifiedTrack :: acc
                , missingFavourites
                )


playlistIdentifier :
    List Favourite
    -> Maybe IdentifiedTrack
    -> Track
    -> ( List IdentifiedTrack, List Favourite, List IdentifiedPlaylistTrack )
    -> ( List IdentifiedTrack, List Favourite, List IdentifiedPlaylistTrack )
playlistIdentifier favourites nowPlaying track ( acc, reducFavourites, reducPlaylistTracks ) =
    let
        matcher =
            trackWithIdentifiedPlaylistTrackMatcher track

        ( matches, remainingPlaylistTracks ) =
            List.foldl
                (\playlistTrack acc ->
                    if matcher playlistTrack then
                        Tuple.mapFirst ((::) playlistTrack) acc
                    else
                        Tuple.mapSecond ((::) playlistTrack) acc
                )
                ( [], [] )
                reducPlaylistTracks

        ( identifiedTracks, remainingMissingFavourites ) =
            List.foldl
                (\( { index }, _ ) ->
                    defaultIdentifier favourites nowPlaying (Just index) track
                )
                ( [], reducFavourites )
                matches
    in
        ( List.append identifiedTracks acc
        , remainingMissingFavourites
        , remainingPlaylistTracks
        )



-- Favourites


isFavourite : Track -> (Favourite -> Bool)
isFavourite track =
    let
        lartist =
            String.toLower track.tags.artist

        ltitle =
            String.toLower track.tags.title
    in
        Favourites.matcher lartist ltitle



-- Playlists


identifyPlaylistTracks : Playlist -> List IdentifiedPlaylistTrack
identifyPlaylistTracks playlist =
    List.indexedMap identifyPlaylistTrack playlist.tracks


identifyPlaylistTrack : Int -> PlaylistTrack -> IdentifiedPlaylistTrack
identifyPlaylistTrack index playlistTrack =
    (,) { index = index } playlistTrack



-- Make tracks


makeMissingFavouriteTrack : Favourite -> IdentifiedTrack
makeMissingFavouriteTrack fav =
    let
        tags =
            { disc = 1
            , nr = 0
            , artist = fav.artist
            , title = fav.title
            , album = "<missing>"
            , genre = Nothing
            , picture = Nothing
            , year = Nothing
            }
    in
        (,)
            { indexInPlaylist = Nothing
            , isFavourite = True
            , isMissing = True
            , isNowPlaying = False
            }
            { tags = tags
            , id = missingId
            , path = missingId
            , sourceId = missingId
            }


makeMissingPlaylistTrack : IdentifiedPlaylistTrack -> IdentifiedTrack
makeMissingPlaylistTrack ( identifiers, playlistTrack ) =
    let
        tags =
            { disc = 1
            , nr = 0
            , artist = playlistTrack.artist
            , title = playlistTrack.title
            , album = playlistTrack.album
            , genre = Nothing
            , picture = Nothing
            , year = Nothing
            }
    in
        (,)
            { indexInPlaylist = Just identifiers.index
            , isFavourite = False
            , isMissing = True
            , isNowPlaying = False
            }
            { tags = tags
            , id = missingId
            , path = missingId
            , sourceId = missingId
            }
