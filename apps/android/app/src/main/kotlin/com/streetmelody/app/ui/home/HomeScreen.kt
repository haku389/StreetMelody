package com.streetmelody.app.ui.home

import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.border
import androidx.compose.ui.draw.shadow
import com.streetmelody.app.R
import com.streetmelody.app.ui.components.PastelCard
import com.streetmelody.app.ui.components.PastelButton
import com.streetmelody.app.ui.components.pastelClickable
import com.streetmelody.app.ui.components.WelcomeHero
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import com.streetmelody.app.data.model.closestToCompletion
import com.streetmelody.app.data.model.collectableCandidateIndex
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.streetmelody.app.data.model.Track
import com.streetmelody.app.ui.components.ArtBlock
import com.streetmelody.app.ui.components.ProgressBar
import com.streetmelody.app.ui.theme.MelodyColors
import com.streetmelody.app.viewmodel.AppViewModel
import com.streetmelody.app.viewmodel.Screen
import com.streetmelody.app.viewmodel.Tab

@Composable
fun HomeScreen(vm: AppViewModel) {
    val user        by vm.user.collectAsState()
    val collection  by vm.collection.collectAsState()
    val mission     by vm.mission.collectAsState()
    val homeState   by vm.homeState.collectAsState()
    val tracks      by vm.tracks.collectAsState()
    val guideFinished by vm.guideFinished.collectAsState()
    val encounter by vm.encounter.collectAsState()
    var guideStep by rememberSaveable { mutableIntStateOf(0) }

    LazyColumn(
        contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 22.dp, bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Header
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    Modifier.size(54.dp).clip(CircleShape)
                        .background(Color(0xFFE8DFF7)),
                    contentAlignment = Alignment.Center
                ) { Text("🎵", fontSize = 22.sp) }

                Column(Modifier.weight(1f)) {
                    Text("YOUR DAILY SOUNDTRACK", fontSize = 7.sp, letterSpacing = 1.sp, color = MelodyColors.Muted)
                    Text("こんにちは、${user?.name ?: "音楽好き"}さん ☀", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    Text("Lv.${user?.level ?: 0}", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                    Spacer(Modifier.height(4.dp))
                    ProgressBar(progress = (user?.level ?: 0) / 100f)
                }

                CoinPill(coins = user?.coins ?: 0)
            }
        }

        if (!guideFinished) item {
            FirstDiscoveryGuide(step = guideStep, onNext = {
                if (guideStep < 2) guideStep++ else { vm.finishGuide(); vm.setTab(Tab.EXCHANGE) }
            }, onBack = { guideStep-- }, onSkip = vm::finishGuide)
        }

        item { WelcomeHero { vm.setTab(Tab.EXCHANGE) } }

        val nearlyComplete = closestToCompletion(tracks.values)
        item {
            if (nearlyComplete.isNotEmpty()) MlCard {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("あと少しで完成", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Text("今日の一歩を、この曲に。", fontSize = 10.sp, color = MelodyColors.Muted)
                        }
                        TextButton(onClick = { guideStep = 0; vm.reopenGuide() }) { Text("使い方", fontSize = 11.sp) }
                    }
                    nearlyComplete.forEach { track ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            ArtBlock(track.color, Modifier.size(48.dp), thumbnailUrl = track.artworkUrl)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(track.displayTitle, maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                Text("あと${track.pieceCount - track.ownedPieces.size}ピース · ${track.ownedPieces.size} / ${track.pieceCount}", fontSize = 10.sp, color = MelodyColors.Muted)
                                ProgressBar(track.progress)
                            }
                            TextButton(onClick = { vm.continueCollecting(track.id) }) { Text(if (collectableCandidateIndex(track, encounter) >= 0) "集める" else "見る", fontSize = 11.sp) }
                        }
                    }
                }
            } else if (guideFinished) TextButton(onClick = { guideStep = 0; vm.reopenGuide() }) { Text("はじめての方へ · 使い方を見る", color = MelodyColors.Muted, fontSize = 11.sp) }
        }

        // Current daily track keeps its actual artwork and progress.
        item {
            val hero = homeState.heroTrack
            if (hero != null) MlCard {
                Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ArtBlock(color = hero.color, thumbnailUrl = hero.artworkUrl, modifier = Modifier.size(104.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("今日のメロディ", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                        Text(hero.displayTitle, fontSize = 14.sp, fontWeight = FontWeight.Black, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("${hero.ownedPieces.size} / ${hero.pieceCount}", fontSize = 20.sp, fontWeight = FontWeight.Black, lineHeight = 20.sp)
                            Text("ピース", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                        }
                        ProgressBar(progress = hero.progress)
                        val rem = maxOf(hero.pieceCount - hero.ownedPieces.size, 0)
                        Text(if (rem > 0) "あと${rem}ピースで完成！" else "完成！", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted)
                        PastelButton("近距離交換をはじめる", Modifier.fillMaxWidth()) {
                            vm.setTab(Tab.EXCHANGE)
                        }
                    }
                }
            }
        }

        // Collection
        item {
            MlCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("コレクション", fontSize = 14.sp, fontWeight = FontWeight.Black)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        StatTile("曲パズル", "${collection?.completedPuzzles ?: 0} / ${collection?.totalPuzzles ?: 0}", Modifier.weight(1f))
                        StatTile("アーティスト", "${collection?.completedArtists ?: 0} / ${collection?.totalArtists ?: 0}", Modifier.weight(1f), MelodyColors.Rose)
                        StatTile("プレイリスト", "${collection?.playlists ?: 0}", Modifier.weight(1f), MelodyColors.Honey)
                    }
                }
            }
        }

        // Mission
        item {
            MlCard {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("${mission?.label ?: "デイリー"}ミッション", fontSize = 13.sp, fontWeight = FontWeight.Black)
                        ProgressBar(progress = mission?.progress ?: 0f)
                    }
                    Text("${mission?.current ?: 0} / ${mission?.target ?: 5}", fontSize = 14.sp, fontWeight = FontWeight.Black)
                }
            }
        }

        // Recent tracks
        item {
            MlCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("最近追加した曲", fontSize = 14.sp, fontWeight = FontWeight.Black)
                        TextButton(onClick = { vm.setTab(Tab.PLAYLIST) }) {
                            Text("すべて見る", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Primary)
                        }
                    }
                    if (homeState.recentTracks.isEmpty()) {
                        Text("次のすれちがいで、新しい曲に出会おう。", fontSize = 11.sp, color = MelodyColors.Muted)
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        homeState.recentTracks.take(3).forEach { track ->
                            SongTile(track = track, modifier = Modifier.weight(1f)) {
                                val screen = if (track.isUnlocked) Screen.Puzzle(track.id) else Screen.Mystery(track.id)
                                vm.navigate(screen)
                            }
                        }
                    }
                }
            }
        }
        item {
            PastelCard {
                Box(Modifier.fillMaxWidth().heightIn(min = 120.dp).pastelClickable { vm.setTab(Tab.PLAYLIST) }) {
                    Image(painterResource(R.drawable.pastel_cozy_room), contentDescription = null,
                        contentScale = ContentScale.Crop, modifier = Modifier.matchParentSize())
                    Column(Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xB349335F))))
                        .padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("まだ知らない、好きな音に。", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text("今日のプレイリストを見る ↗", color = Color.White, fontSize = 11.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun FirstDiscoveryGuide(step: Int, onNext: () -> Unit, onBack: () -> Unit, onSkip: () -> Unit) {
    val titles = listOf("すれちがいから、好きな音へ。", "小さなピースを、ひとつずつ。", "あと少しを、今日の楽しみに。")
    val descriptions = listOf("届いたメロディから、気になる曲を選んでみましょう。", "候補には受け取れるピースが表示されます。所持済みか確認してから選べます。", "集めかけの曲はホームに並びます。まずは最初の出会いを見てみましょう。")
    MlCard {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("はじめてのStreetMelody · ${step + 1} / 3", fontSize = 10.sp, color = MelodyColors.Muted)
                TextButton(onClick = onSkip) { Text("あとで", fontSize = 11.sp) }
            }
            Text(titles[step], fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(descriptions[step], fontSize = 12.sp, color = MelodyColors.Muted)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                if (step > 0) TextButton(onClick = onBack) { Text("戻る") }
                Spacer(Modifier.weight(1f))
                PastelButton(if (step < 2) "次へ" else "届いたメロディを見る", onClick = onNext)
            }
        }
    }
}

@Composable
private fun CoinPill(coins: Int) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.86f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("🪙")
        Text("$coins", fontSize = 12.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun StatTile(label: String, value: String, modifier: Modifier = Modifier, tint: Color = MelodyColors.Surface2) {
    Column(
        modifier = modifier
            .shadow(3.dp, RoundedCornerShape(18.dp))
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.linearGradient(listOf(tint.copy(alpha = .7f), tint)))
            .border(1.dp, Color.White.copy(alpha = .7f), RoundedCornerShape(18.dp))
            .padding(horizontal = 8.dp, vertical = 12.dp),
    ) {
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted, maxLines = 1)
        Spacer(Modifier.height(5.dp))
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun SongTile(track: Track, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(modifier = modifier.pastelClickable(onClick = onClick)) {
        ArtBlock(color = track.color, thumbnailUrl = track.artworkUrl, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
        Spacer(Modifier.height(8.dp))
        Text(if (track.isUnlocked) track.title ?: "—" else "未解放メロディ",
            fontSize = 11.sp, fontWeight = FontWeight.Black, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(if (track.isUnlocked) track.artistName ?: "—" else "???",
            fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MelodyColors.Muted, maxLines = 1)
    }
}

@Composable
fun MlCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    PastelCard(modifier, content)
}
