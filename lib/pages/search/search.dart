import 'package:fl_query_hooks/fl_query_hooks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:platform_ui/platform_ui.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/components/album/album_card.dart';
import 'package:spotube/components/shared/shimmers/shimmer_playbutton_card.dart';
import 'package:spotube/components/shared/fallbacks/anonymous_fallback.dart';
import 'package:spotube/components/shared/page_window_title_bar.dart';
import 'package:spotube/components/shared/track_table/track_tile.dart';
import 'package:spotube/components/shared/waypoint.dart';
import 'package:spotube/components/artist/artist_card.dart';
import 'package:spotube/components/playlist/playlist_card.dart';
import 'package:spotube/hooks/use_breakpoints.dart';
import 'package:spotube/models/current_playlist.dart';
import 'package:spotube/provider/auth_provider.dart';
import 'package:spotube/provider/playback_provider.dart';
import 'package:spotube/provider/spotify_provider.dart';
import 'package:spotube/services/queries/queries.dart';

import 'package:spotube/utils/platform.dart';
import 'package:spotube/utils/primitive_utils.dart';
import 'package:spotube/utils/type_conversion_utils.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';

final searchTermStateProvider = StateProvider<String>((ref) => "");

class SearchPage extends HookConsumerWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final Auth auth = ref.watch(authProvider);
    final albumController = useScrollController();
    final playlistController = useScrollController();
    final artistController = useScrollController();
    final breakpoint = useBreakpoints();

    final getVariables = useCallback(
      () => Tuple2(
        ref.read(searchTermStateProvider),
        ref.read(spotifyProvider),
      ),
      [],
    );

    final searchTrack = useInfiniteQuery(
      job: Queries.search.get(SearchType.track.key),
      externalData: getVariables(),
    );
    final searchAlbum = useInfiniteQuery(
      job: Queries.search.get(SearchType.album.key),
      externalData: getVariables(),
    );
    final searchPlaylist = useInfiniteQuery(
      job: Queries.search.get(SearchType.playlist.key),
      externalData: getVariables(),
    );
    final searchArtist = useInfiniteQuery(
      job: Queries.search.get(SearchType.artist.key),
      externalData: getVariables(),
    );

    void onSearch() {
      for (final query in [
        searchTrack,
        searchAlbum,
        searchPlaylist,
        searchArtist,
      ]) {
        query.enabled = false;
        query.fetched = true;
        query.setExternalData(getVariables());
        query.refetch();
      }
    }

    return SafeArea(
      child: PlatformScaffold(
        appBar: kIsDesktop && !kIsMacOS ? PageWindowTitleBar() : null,
        body: auth.isAnonymous
            ? const AnonymousFallback()
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    color: PlatformTheme.of(context).scaffoldBackgroundColor,
                    child: PlatformTextField(
                      onChanged: (value) {
                        ref.read(searchTermStateProvider.notifier).state =
                            value;
                      },
                      prefixIcon: Icons.search_rounded,
                      prefixIconColor: PlatformProperty.only(
                        ios:
                            PlatformTheme.of(context).textTheme?.caption?.color,
                        other: null,
                      ).resolve(platform!),
                      placeholder: "Search...",
                      onSubmitted: (value) {
                        onSearch();
                      },
                    ),
                  ),
                  HookBuilder(
                    builder: (context) {
                      Playback playback = ref.watch(playbackProvider);
                      List<AlbumSimple> albums = [];
                      List<Artist> artists = [];
                      List<Track> tracks = [];
                      List<PlaylistSimple> playlists = [];
                      final pages = [
                        ...searchTrack.pages,
                        ...searchAlbum.pages,
                        ...searchPlaylist.pages,
                        ...searchArtist.pages,
                      ].expand<Page>((page) => page ?? []).toList();
                      for (MapEntry<int, Page> page in pages.asMap().entries) {
                        for (var item in page.value.items ?? []) {
                          if (item is AlbumSimple) {
                            albums.add(item);
                          } else if (item is PlaylistSimple) {
                            playlists.add(item);
                          } else if (item is Artist) {
                            artists.add(item);
                          } else if (item is Track) {
                            tracks.add(item);
                          }
                        }
                      }
                      return Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tracks.isNotEmpty)
                                  PlatformText.headline("Songs"),
                                if (searchTrack.isLoading &&
                                    !searchTrack.isFetchingNextPage)
                                  const PlatformCircularProgressIndicator()
                                else if (searchTrack.hasError)
                                  PlatformText(searchTrack
                                      .error?[searchTrack.pageParams.last])
                                else
                                  ...tracks.asMap().entries.map((track) {
                                    String duration =
                                        "${track.value.duration?.inMinutes.remainder(60)}:${PrimitiveUtils.zeroPadNumStr(track.value.duration?.inSeconds.remainder(60) ?? 0)}";
                                    return TrackTile(
                                      playback,
                                      track: track,
                                      duration: duration,
                                      isActive:
                                          playback.track?.id == track.value.id,
                                      onTrackPlayButtonPressed:
                                          (currentTrack) async {
                                        var isPlaylistPlaying =
                                            playback.playlist?.id != null &&
                                                playback.playlist?.id ==
                                                    currentTrack.id;
                                        if (!isPlaylistPlaying) {
                                          playback.playPlaylist(
                                            CurrentPlaylist(
                                              tracks: [currentTrack],
                                              id: currentTrack.id!,
                                              name: currentTrack.name!,
                                              thumbnail: TypeConversionUtils
                                                  .image_X_UrlString(
                                                currentTrack.album?.images,
                                                placeholder:
                                                    ImagePlaceholder.albumArt,
                                              ),
                                            ),
                                          );
                                        } else if (isPlaylistPlaying &&
                                            currentTrack.id != null &&
                                            currentTrack.id !=
                                                playback.track?.id) {
                                          playback.play(currentTrack);
                                        }
                                      },
                                    );
                                  }),
                                if (searchTrack.hasNextPage &&
                                    tracks.isNotEmpty)
                                  Center(
                                    child: PlatformTextButton(
                                      onPressed: searchTrack.isFetchingNextPage
                                          ? null
                                          : () => searchTrack.fetchNextPage(),
                                      child: searchTrack.isFetchingNextPage
                                          ? const PlatformCircularProgressIndicator()
                                          : const PlatformText("Load more"),
                                    ),
                                  ),
                                if (playlists.isNotEmpty)
                                  PlatformText.headline("Playlists"),
                                const SizedBox(height: 10),
                                ScrollConfiguration(
                                  behavior:
                                      ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                                  child: Scrollbar(
                                    scrollbarOrientation:
                                        breakpoint > Breakpoints.md
                                            ? ScrollbarOrientation.bottom
                                            : ScrollbarOrientation.top,
                                    controller: playlistController,
                                    child: Waypoint(
                                      onTouchEdge: () {
                                        searchPlaylist.fetchNextPage();
                                      },
                                      controller: playlistController,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        controller: playlistController,
                                        child: Row(
                                          children: [
                                            ...playlists.mapIndexed(
                                              (i, playlist) {
                                                if (i == playlists.length - 1 &&
                                                    searchPlaylist
                                                        .hasNextPage) {
                                                  return const ShimmerPlaybuttonCard(
                                                      count: 1);
                                                }
                                                return PlaylistCard(playlist);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (searchPlaylist.isLoading &&
                                    !searchPlaylist.isFetchingNextPage)
                                  const PlatformCircularProgressIndicator(),
                                if (searchPlaylist.hasError)
                                  PlatformText(searchPlaylist
                                      .error?[searchPlaylist.pageParams.last]),
                                const SizedBox(height: 20),
                                if (artists.isNotEmpty)
                                  PlatformText.headline("Artists"),
                                const SizedBox(height: 10),
                                ScrollConfiguration(
                                  behavior:
                                      ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                                  child: Scrollbar(
                                    controller: artistController,
                                    child: Waypoint(
                                      controller: artistController,
                                      onTouchEdge: () {
                                        searchArtist.fetchNextPage();
                                      },
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        controller: artistController,
                                        child: Row(
                                          children: [
                                            ...artists.mapIndexed(
                                              (i, artist) {
                                                if (i == artists.length - 1 &&
                                                    searchArtist.hasNextPage) {
                                                  return const ShimmerPlaybuttonCard(
                                                      count: 1);
                                                }
                                                return Container(
                                                  margin: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 15),
                                                  child: ArtistCard(artist),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (searchArtist.isLoading &&
                                    !searchArtist.isFetchingNextPage)
                                  const PlatformCircularProgressIndicator(),
                                if (searchArtist.hasError)
                                  PlatformText(searchArtist
                                      .error?[searchArtist.pageParams.last]),
                                const SizedBox(height: 20),
                                if (albums.isNotEmpty)
                                  PlatformText.subheading("Albums"),
                                const SizedBox(height: 10),
                                ScrollConfiguration(
                                  behavior:
                                      ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                                  child: Scrollbar(
                                    controller: albumController,
                                    child: Waypoint(
                                      controller: albumController,
                                      onTouchEdge: () {
                                        searchAlbum.fetchNextPage();
                                      },
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        controller: albumController,
                                        child: Row(
                                          children: [
                                            ...albums.mapIndexed((i, album) {
                                              if (i == albums.length - 1 &&
                                                  searchAlbum.hasNextPage) {
                                                return const ShimmerPlaybuttonCard(
                                                    count: 1);
                                              }
                                              return AlbumCard(
                                                TypeConversionUtils
                                                    .simpleAlbum_X_Album(
                                                  album,
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (searchAlbum.isLoading &&
                                    !searchAlbum.isFetchingNextPage)
                                  const PlatformCircularProgressIndicator(),
                                if (searchAlbum.hasError)
                                  PlatformText(searchAlbum
                                      .error?[searchAlbum.pageParams.last]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
      ),
    );
  }
}
