package com.streetmelody.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.streetmelody.app.ui.theme.MelodyColors
import com.streetmelody.app.data.model.puzzleGridSize

/**
 * 24ピースは6×4、それ以外はAPIのピース数に合わせて表示する。
 *
 * 所持ピースだけサムネイルを見せ、未所持は lockedピース（淡い紫）で覆う。
 * - [revealAll]: 全ピース表示（フル表示）
 * - [mosaic]: ぼかし（未解放曲のフル表示などネタバレ防止）
 */
@Composable
fun PuzzlePieces(
    thumbnailUrl: String?,
    ownedPieces: List<Int>,
    color: String,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 16.dp,
    revealAll: Boolean = false,
    mosaic: Boolean = false,
    pieceCount: Int = 24,
) {
    val (cols, rows) = puzzleGridSize(pieceCount)
    val gap = 2.dp
    val lockedColor = Color(0xFFE3DAF5)
    val borderColor = Color(0xFFE0D8F7)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(if (pieceCount == 24) 16f / 9f else cols.toFloat() / rows)
            .clip(RoundedCornerShape(cornerRadius))
            .border(1.dp, borderColor, RoundedCornerShape(cornerRadius))
    ) {
        // サムネイル（架空曲はグラデーション）。未解放はモザイク。
        if (thumbnailUrl != null) {
            AsyncImage(
                model = thumbnailUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .then(if (mosaic) Modifier.blur(16.dp) else Modifier),
            )
        } else {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Brush.linearGradient(MelodyColors.artColors(color)))
            )
        }

        // 6×4 グリッド：未表示セルを lockedピースで覆う（ギャップがピースの境界線になる）
        Column(
            Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(gap),
        ) {
            for (r in 0 until rows) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(gap),
                ) {
                    for (c in 0 until cols) {
                        val n = r * cols + c + 1
                        val visible = n <= pieceCount && (revealAll || ownedPieces.contains(n))
                        Box(
                            Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .clip(RoundedCornerShape(3.dp))
                                .then(if (visible) Modifier else Modifier.background(lockedColor))
                        )
                    }
                }
            }
        }
    }
}
