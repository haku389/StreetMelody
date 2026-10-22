package com.streetmelody.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ─── User ──────────────────────────────────────

@Serializable
data class User(
    val id: String,
    val name: String,
    val level: Int,
    val exp: Int,
    val coins: Int,
)

// ─── Track ─────────────────────────────────────

@Serializable
data class Track(
    val id: String,
    val artistId: String,
    val pieceCount: Int,
    val rewardCoins: Int,
    val rewardExp: Int,
    val color: String,
    val tone: String? = null,
    val title: String? = null,         // 未解放は null
    val artistName: String? = null,    // 未解放は null
    val isUnlocked: Boolean = false,
    val hintLevel: Int = 0,
    val answerReady: Boolean = false,
    val maskedLabel: String? = null,
    val choices: List<String> = emptyList(),
    val ownedPieces: List<Int> = emptyList(),
    val youtubeVideoId: String? = null,
    val thumbnailUrl: String? = null,
) {
    val displayTitle: String get() = if (isUnlocked) title ?: "メロディ" else maskedLabel ?: "未解放メロディ"
    val displayArtist: String get() = artistName ?: "???"
    val isComplete: Boolean get() = ownedPieces.size >= pieceCount
    val progress: Float get() = if (pieceCount == 0) 0f else ownedPieces.size.toFloat() / pieceCount

    /** 実在する YouTube 動画のサムネイル URL（架空曲 official-* は除外）。
     *  i.ytimg.com（画像CDN）の mqdefault は黒帯のないクリーンな 16:9。 */
    val youtubeThumbnailUrl: String?
        get() = youtubeVideoId
            ?.takeIf { !it.startsWith("official-") }
            ?.let { "https://i.ytimg.com/vi/$it/mqdefault.jpg" }

    /** 解放済みの曲アートに使うサムネイル（未解放はネタバレ防止で表示しない） */
    val artworkUrl: String? get() = if (isUnlocked) thumbnailUrl ?: youtubeThumbnailUrl else null
}

// ─── Encounter ─────────────────────────────────

@Serializable
data class Encounter(
    val id: String,
    val locationLabel: String,
    val rewardCoins: Int,
    val expiresAt: String,
    val candidates: List<Candidate>,
)

@Serializable
data class Candidate(
    val id: String,
    val trackId: String,
    val pieceNumber: Int,
    val sourceSlot: String,
    val rarity: Int,
    val sortOrder: Int,
)

// ─── Playlist ──────────────────────────────────

@Serializable
data class DailyPlaylist(
    val id: String,
    val date: String,
    val title: String,
    val tracks: List<PlaylistItem>,
)

@Serializable
data class PlaylistItem(
    val trackId: String,
    val artistId: String,
    val color: String,
)

// ─── Mission ───────────────────────────────────

@Serializable
data class Mission(
    val userId: String,
    val date: String,
    val label: String,
    val current: Int,
    val target: Int,
) {
    val progress: Float get() = if (target == 0) 0f else current.toFloat() / target
}

// ─── Collection Summary ─────────────────────────

@Serializable
data class CollectionSummary(
    val completedPuzzles: Int,
    val totalPuzzles: Int,
    val completedArtists: Int,
    val totalArtists: Int,
    val playlists: Int,
)

// ─── API responses ──────────────────────────────

@Serializable
data class SelectPieceResponse(
    val trackId: String,
    val pieceNumber: Int,
    val added: Boolean,
    val nextScreen: String,
)

@Serializable
data class HintResponse(
    val hintLevel: Int,
    val answerReady: Boolean,
)

/** Stable progress ordering; completed and unstarted puzzles are not recommendations. */
fun closestToCompletion(tracks: Collection<Track>): List<Track> = tracks
    .filter { it.pieceCount > 0 && it.ownedPieces.isNotEmpty() && !it.isComplete }
    .sortedWith(compareByDescending<Track> { it.progress }.thenBy { it.id })
    .take(2)

fun collectableCandidateIndex(track: Track, encounter: Encounter?): Int =
    encounter?.candidates?.indexOfFirst { it.trackId == track.id && it.pieceNumber !in track.ownedPieces } ?: -1

fun puzzleGridSize(pieceCount: Int): Pair<Int, Int> {
    if (pieceCount == 24) return 6 to 4
    val count = pieceCount.coerceAtLeast(1)
    val columns = kotlin.math.ceil(kotlin.math.sqrt(count.toDouble())).toInt()
    return columns to ((count + columns - 1) / columns)
}
