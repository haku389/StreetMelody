package com.streetmelody.app.ui.discovery

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.streetmelody.app.data.model.Track
import com.streetmelody.app.ui.components.*
import com.streetmelody.app.ui.theme.MelodyColors
import com.streetmelody.app.viewmodel.*

@Composable
private fun DiscoveryPage(title: String, subtitle: String, content: LazyListScope.() -> Unit) {
    LazyColumn(contentPadding = PaddingValues(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            val symbol = when (title) { "届いたメロディ" -> "♫"; "曲パズル" -> "◈"; "アーティスト" -> "☆"; "未解放メロディ" -> "♧"; else -> "♫" }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("YOUR LITTLE MUSIC WORLD", fontSize = 7.sp, letterSpacing = 1.5.sp, color = MelodyColors.Muted)
                    Text(title, fontSize = 25.sp, fontWeight = FontWeight.Bold, color = MelodyColors.Ink)
                    Text(subtitle, fontSize = 11.sp, color = MelodyColors.Muted)
                }
                Box(Modifier.size(44.dp).background(MelodyColors.Surface2, RoundedCornerShape(15.dp))
                    .border(1.dp, Color.White, RoundedCornerShape(15.dp)), contentAlignment = Alignment.Center) {
                    Text(symbol, fontSize = 23.sp, color = MelodyColors.Primary)
                }
            }
        }
        content()
    }
}

@Composable
fun TrackRow(track: Track, onClick: () -> Unit) {
    PastelCard {
        Row(Modifier.fillMaxWidth().pastelClickable(onClick = onClick).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ArtBlock(track.color, Modifier.size(56.dp), thumbnailUrl = track.artworkUrl)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(track.displayTitle, maxLines = 1, overflow = TextOverflow.Ellipsis, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                Text(track.displayArtist, fontSize = 11.sp, color = MelodyColors.Muted)
                ProgressBar(track.progress)
                Text(if (track.isComplete) "完成！" else "あと${track.pieceCount - track.ownedPieces.size}ピース · ${track.ownedPieces.size} / ${track.pieceCount}",
                    fontSize = 10.sp, color = MelodyColors.Muted)
            }
            Box(Modifier.size(30.dp).background(MelodyColors.Surface2, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                Text("›", color = MelodyColors.Primary, fontSize = 22.sp)
            }
        }
    }
}

@Composable
fun CollectionScreen(vm: AppViewModel) {
    val tracks by vm.tracks.collectAsState()
    DiscoveryPage("曲パズル", "集めたピースから、好きな曲を増やそう。") {
        item { PastelTabIntro("◈", "好きな音が、少しずつ形に。", "集めたピースは、あなただけの音楽の記録。", listOf("集めたピース" to "${tracks.values.sumOf { it.ownedPieces.size }}枚", "完成した曲" to "${tracks.values.count { it.isComplete }}曲")) }
        if (tracks.isEmpty()) item { Text("まだ曲がありません。届いたメロディを確認してみましょう。", color = MelodyColors.Muted) }
        items(tracks.values.sortedWith(compareBy<Track> { it.isComplete }.thenByDescending { it.progress }.thenBy { it.id }), key = { it.id }) { track ->
            TrackRow(track) { vm.openTrack(track.id) }
        }
    }
}

@Composable
fun ExchangeScreen(vm: AppViewModel) {
    val encounter by vm.encounter.collectAsState()
    val tracks by vm.tracks.collectAsState()
    val selected by vm.selectedCandidate.collectAsState()
    val busy by vm.actionBusy.collectAsState()
    var confirm by rememberSaveable { mutableStateOf(false) }
    DiscoveryPage("届いたメロディ", "気になる曲を選んで、ピースを1枚受け取ろう。") {
        val enc = encounter
        item { PastelTabIntro("♫", "ひとつの出会いから、次の好きへ。", "候補を選んで、新しいピースを受け取ろう。", listOf("今日の候補" to "${enc?.candidates?.size ?: 0}曲", "未所持ピース" to "${enc?.candidates?.count { candidate -> tracks[candidate.trackId]?.let { candidate.pieceNumber !in it.ownedPieces } == true } ?: 0}枚")) }
        if (enc == null || enc.candidates.isEmpty()) {
            item { Text("受け取れる候補はまだありません。また新しい出会いを待ちましょう。", color = MelodyColors.Muted) }
        } else {
            item { Text("${enc.locationLabel} · ${enc.candidates.size}曲の候補", color = MelodyColors.Muted, fontSize = 11.sp) }
            items(enc.candidates.withIndex().toList(), key = { it.value.id }) { indexed ->
                val candidate = indexed.value
                val track = tracks[candidate.trackId]
                val on = selected == indexed.index
                PastelCard(modifier = Modifier.border(if (on) 2.dp else 0.dp, if (on) MelodyColors.Primary2 else Color.Transparent, RoundedCornerShape(24.dp))) {
                    Column(Modifier.fillMaxWidth().pastelClickable(enabled = !busy && track != null) { vm.selectCandidate(indexed.index) }.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(selected = on, onClick = { vm.selectCandidate(indexed.index) }, enabled = !busy && track != null)
                            Column(Modifier.weight(1f)) {
                                Text(track?.displayTitle ?: "曲情報を読み込めませんでした", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                Text(track?.displayArtist ?: "", color = MelodyColors.Muted, fontSize = 11.sp)
                            }
                            if (track != null) ArtBlock(track.color, Modifier.size(48.dp), thumbnailUrl = track.artworkUrl)
                        }
                        val owned = track?.ownedPieces?.contains(candidate.pieceNumber) == true
                        Text("${candidate.sourceSlot} · ピース ${candidate.pieceNumber}" + if (owned) "（所持済み）" else "（未所持）", fontSize = 11.sp, color = MelodyColors.Muted)
                        if (on && track != null) {
                            PastelButton(if (busy) "受け取り中…" else if (owned) "所持済みのピースを確認する" else "このピースを受け取る", modifier = Modifier.fillMaxWidth(), enabled = !busy) { confirm = true }
                        }
                    }
                }
            }
        }
    }
    if (confirm) AlertDialog(
        onDismissRequest = { if (!busy) confirm = false },
        title = { Text("このピースを受け取りますか？") },
        text = { Text("選んだ曲のピースを受け取ります。所持済みの場合、新しいピースは増えません。") },
        confirmButton = { TextButton(onClick = { confirm = false; vm.confirmPiece() }, enabled = !busy) { Text("受け取る") } },
        dismissButton = { TextButton(onClick = { confirm = false }) { Text("選び直す") } },
    )
}

@Composable
fun ArtistScreen(vm: AppViewModel, artistId: String? = null) {
    val tracks by vm.tracks.collectAsState()
    val groups = tracks.values.groupBy { it.artistId }.toSortedMap()
    val artistTracks = if (artistId == null) emptyList() else groups[artistId].orEmpty().sortedBy { it.id }
    val name = artistTracks.firstNotNullOfOrNull { it.artistName } ?: "名前未解放のアーティスト"
    DiscoveryPage(if (artistId == null) "アーティスト" else name, "曲の完成を重ねて、コレクションを育てよう。") {
        item { PastelTabIntro("☆", if (artistId == null) "好きなアーティストと、もっと近くに。" else "ひとつずつ、音を集めよう。", "曲のピースがつなぐ、あなただけのコレクション。", listOf("アーティスト" to "${if (artistId == null) groups.size else 1}組", "完成した曲" to "${(if (artistId == null) tracks.values else artistTracks).count { it.isComplete }}曲")) }
        if (artistId != null) {
            items(artistTracks, key = { it.id }) { track -> TrackRow(track) { vm.openTrack(track.id) } }
        } else {
            if (groups.isEmpty()) item { Text("曲を集めると、ここにアーティストが並びます。", color = MelodyColors.Muted) }
            items(groups.entries.toList(), key = { it.key }) { (id, group) ->
                PastelCard {
                    Column(Modifier.fillMaxWidth().pastelClickable { vm.navigate(Screen.Artist(id)) }.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Box(Modifier.size(42.dp).background(MelodyColors.Surface2, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) { Text("♫", color = MelodyColors.Primary, fontSize = 24.sp) }
                            Text(group.firstNotNullOfOrNull { it.artistName } ?: "名前未解放のアーティスト", fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            Text("›", color = MelodyColors.Primary, fontSize = 22.sp)
                        }
                        Text("${group.count { it.isComplete }} / ${group.size} 曲完成 · ${group.sumOf { it.ownedPieces.size }} ピース", fontSize = 11.sp, color = MelodyColors.Muted)
                        ProgressBar(if (group.sumOf { it.pieceCount } == 0) 0f else group.sumOf { it.ownedPieces.size }.toFloat() / group.sumOf { it.pieceCount })
                    }
                }
            }
        }
    }
}

@Composable
fun PlaylistScreen(vm: AppViewModel) {
    val playlist by vm.playlist.collectAsState()
    val tracks by vm.tracks.collectAsState()
    DiscoveryPage(playlist?.title ?: "今日のプレイリスト", "すれちがいから届いた音を、もう一度。") {
        val entries = playlist?.tracks.orEmpty()
        item { PastelTabIntro("♫", "今日の音を、もう一度。", "出会った曲を並べた、あなたの小さなサウンドトラック。", listOf("届いた曲" to "${entries.size}曲", "解放した曲" to "${entries.count { tracks[it.trackId]?.isUnlocked == true }}曲")) }
        if (entries.isEmpty()) item { Text("今日の曲はまだありません。届いたメロディを確認してみましょう。", color = MelodyColors.Muted) }
        items(entries.withIndex().toList(), key = { "${it.index}:${it.value.trackId}" }) { (_, entry) ->
            val track = tracks[entry.trackId]
            if (track != null) TrackRow(track) { vm.openTrack(track.id) }
            else Text("曲情報を取得できませんでした。ホームで再読み込みしてください。", color = MelodyColors.Muted)
        }
    }
}

@Composable
fun MysteryScreen(vm: AppViewModel, trackId: String) {
    val tracks by vm.tracks.collectAsState()
    val busy by vm.actionBusy.collectAsState()
    val track = tracks[trackId]
    DiscoveryPage("未解放メロディ", "ピースを集めながら、曲名のヒントを見つけよう。") {
        if (track == null) item { Text("曲を取得できませんでした。前の画面に戻って再読み込みしてください。") }
        else item {
            PastelCard {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    PuzzlePieces(track.thumbnailUrl ?: track.youtubeThumbnailUrl, track.ownedPieces, track.color, pieceCount = track.pieceCount)
                    Text(track.displayTitle, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    Text("${track.ownedPieces.size} / ${track.pieceCount} ピース", color = MelodyColors.Muted)
                    Text("ヒント ${track.hintLevel} / 2", fontSize = 12.sp, color = MelodyColors.Muted)
                    if (track.hintLevel < 2) PastelButton("次のヒントを見る", enabled = !busy) { vm.applyHint(track.id, if (track.hintLevel == 0) HintKind.HINT1 else HintKind.HINT2) }
                    if (track.hintLevel >= 2 && !track.answerReady) PastelButton("曲名の解放へ進む", enabled = !busy) { vm.applyHint(track.id, HintKind.ANSWER) }
                    if (track.answerReady) PastelButton("曲名を解放する", enabled = !busy) { vm.unlockTrack(track.id) }
                    OutlinedButton(onClick = { vm.setTab(Tab.EXCHANGE) }, enabled = !busy) { Text("ほかのピースを集める") }
                }
            }
        }
    }
}
