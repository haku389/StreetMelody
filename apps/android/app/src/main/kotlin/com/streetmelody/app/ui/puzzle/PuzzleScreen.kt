package com.streetmelody.app.ui.puzzle

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.streetmelody.app.data.model.Track
import com.streetmelody.app.ui.components.PastelCard
import com.streetmelody.app.ui.components.ProgressBar
import com.streetmelody.app.ui.components.PuzzlePieces
import com.streetmelody.app.ui.theme.MelodyColors
import com.streetmelody.app.viewmodel.AppViewModel

/** Detail route always displays the selected track, rather than a dictionary's first item. */
@Composable
fun PuzzleScreen(vm: AppViewModel, trackId: String) {
    val tracks by vm.tracks.collectAsState()
    val track = tracks[trackId]

    if (track == null) {
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text("パズルがありません", color = MelodyColors.Muted, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        }
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            track.displayTitle,
            fontSize = 18.sp, fontWeight = FontWeight.Black, color = MelodyColors.Ink,
        )
        Text(
            track.displayArtist,
            fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MelodyColors.Muted,
        )

        PastelCard {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                PuzzlePieces(
                    thumbnailUrl = track.thumbnailUrl ?: track.youtubeThumbnailUrl,
                    ownedPieces = track.ownedPieces,
                    color = track.color,
                    cornerRadius = 18.dp,
                    pieceCount = track.pieceCount,
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        "${track.ownedPieces.size} / ${track.pieceCount}",
                        fontSize = 20.sp, fontWeight = FontWeight.Black, color = MelodyColors.Ink,
                    )
                    Spacer(Modifier.weight(1f))
                    val rem = (track.pieceCount - track.ownedPieces.size).coerceAtLeast(0)
                    Text(
                        if (rem > 0) "あと${rem}ピースで完成！" else "🎉 完成！",
                        fontSize = 11.sp, fontWeight = FontWeight.Bold,
                        color = if (rem == 0) Color_1A9E6E else MelodyColors.Muted,
                    )
                }
                ProgressBar(progress = track.progress)
                if (!track.isComplete) Button(onClick = { vm.setTab(com.streetmelody.app.viewmodel.Tab.EXCHANGE) }, modifier = Modifier.fillMaxWidth()) {
                    Text("届いたメロディから集める")
                }
            }
        }
    }
}

private val Color_FFFFFF = androidx.compose.ui.graphics.Color(0xFFFFFFFF)
private val Color_1A9E6E = androidx.compose.ui.graphics.Color(0xFF1A9E6E)
