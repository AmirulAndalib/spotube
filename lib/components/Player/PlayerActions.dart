import 'package:fl_query/fl_query.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/components/Shared/DownloadTrackButton.dart';
import 'package:spotube/components/Shared/HeartButton.dart';
import 'package:spotube/hooks/useForceUpdate.dart';
import 'package:spotube/models/Logger.dart';
import 'package:spotube/provider/Auth.dart';
import 'package:spotube/provider/Playback.dart';
import 'package:spotube/provider/SpotifyDI.dart';
import 'package:spotube/provider/SpotifyRequests.dart';
import 'package:spotube/provider/queries.dart';

class PlayerActions extends HookConsumerWidget {
  final MainAxisAlignment mainAxisAlignment;
  PlayerActions({
    this.mainAxisAlignment = MainAxisAlignment.center,
    Key? key,
  }) : super(key: key);
  final logger = getLogger(PlayerActions);

  @override
  Widget build(BuildContext context, ref) {
    final SpotifyApi spotifyApi = ref.watch(spotifyProvider);
    final Playback playback = ref.watch(playbackProvider);
    final Auth auth = ref.watch(authProvider);
    final update = useForceUpdate();
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        DownloadTrackButton(
          track: playback.currentTrack,
        ),
        if (auth.isLoggedIn)
          FutureBuilder<bool>(
              future: playback.currentTrack?.id != null
                  ? spotifyApi.tracks.me.containsOne(playback.currentTrack!.id!)
                  : Future.value(false),
              initialData: false,
              builder: (context, snapshot) {
                bool isLiked = snapshot.data ?? false;
                return HeartButton(
                    isLiked: isLiked,
                    onPressed: () async {
                      try {
                        if (playback.currentTrack?.id == null) return;
                        isLiked
                            ? await spotifyApi.tracks.me
                                .removeOne(playback.currentTrack!.id!)
                            : await spotifyApi.tracks.me
                                .saveOne(playback.currentTrack!.id!);
                      } catch (e, stack) {
                        logger.e("FavoriteButton.onPressed", e, stack);
                      } finally {
                        update();
                        QueryBowl.of(context).refetchQueries([
                          currentUserSavedTracksQueryJob.queryKey,
                          playlistTracksQueryJob("user-liked-tracks").queryKey,
                        ]);
                      }
                    });
              }),
      ],
    );
  }
}
