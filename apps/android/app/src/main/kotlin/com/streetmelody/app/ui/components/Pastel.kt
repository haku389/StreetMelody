package com.streetmelody.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.streetmelody.app.R
import com.streetmelody.app.ui.theme.MelodyColors

/** Uses the same interaction source as the control, including release and scroll cancellation. */
fun Modifier.pastelPressFeedback(source: MutableInteractionSource): Modifier = composed {
    val pressed by source.collectIsPressedAsState()
    val amount by animateFloatAsState(if (pressed) 1f else 0f,
        animationSpec = tween(if (pressed) 80 else 160), label = "pastelPress")
    val density = LocalDensity.current.density
    graphicsLayer {
        scaleX = 1f - .035f * amount
        scaleY = 1f - .035f * amount
        translationY = 2f * density * amount
        alpha = 1f - .18f * amount
    }
}

fun Modifier.pastelClickable(enabled: Boolean = true, onClick: () -> Unit): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    pastelPressFeedback(source).clickable(interactionSource = source,
        indication = androidx.compose.foundation.LocalIndication.current, enabled = enabled, onClick = onClick)
}

@Composable
fun PastelCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    Box(
        modifier.fillMaxWidth()
            .shadow(7.dp, shape, ambientColor = MelodyColors.Shadow.copy(alpha = .2f), spotColor = MelodyColors.Shadow.copy(alpha = .2f))
            .clip(shape)
            .background(Brush.linearGradient(listOf(MelodyColors.Surface, Color(0xFFFAEEE8))))
            .border(1.dp, Brush.verticalGradient(listOf(Color.White, Color.White.copy(alpha = .4f))), shape)
    ) { content() }
}

@Composable
fun PastelButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Surface(
        onClick = onClick,
        modifier = modifier.heightIn(min = 48.dp).alpha(if (enabled) 1f else .5f).pastelPressFeedback(source),
        interactionSource = source,
        enabled = enabled,
        shape = RoundedCornerShape(14.dp),
        color = Color.Transparent,
        contentColor = Color.White,
        shadowElevation = if (pressed) 1.dp else 4.dp,
    ) {
        Box(
            Modifier.background(Brush.verticalGradient(listOf(MelodyColors.Primary2, MelodyColors.Primary)))
                .border(1.dp, Color.White.copy(alpha = .4f), RoundedCornerShape(14.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) { Text(text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
    }
}

@Composable
fun WelcomeHero(onClick: () -> Unit) {
    val largeText = LocalDensity.current.fontScale > 1.4f
    val shape = RoundedCornerShape(24.dp)
    Box(
        Modifier.fillMaxWidth().shadow(7.dp, shape,
            ambientColor = MelodyColors.Shadow.copy(alpha = .2f), spotColor = MelodyColors.Shadow.copy(alpha = .2f))
            .clip(shape).background(MelodyColors.Surface2)
    ) {
        if (largeText) {
            Column {
                HeroImage(Modifier.fillMaxWidth().height(180.dp))
                HeroCopy(Modifier.padding(20.dp), onClick)
            }
        } else {
            BoxWithConstraints(Modifier.fillMaxWidth().height(240.dp)) {
                HeroImage(Modifier.fillMaxSize())
                HeroCopy(Modifier.padding(start = maxWidth * .44f, top = 23.dp, end = 10.dp), onClick)
            }
        }
    }
}

@Composable
private fun HeroImage(modifier: Modifier) {
    Image(painterResource(R.drawable.pastel_hero), contentDescription = null,
        modifier = modifier, contentScale = ContentScale.Crop)
}

@Composable
private fun HeroCopy(modifier: Modifier, onClick: () -> Unit) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("A LITTLE MUSIC, A LITTLE MAGIC", fontSize = 6.sp, color = Color(0xFF785A91),
            modifier = Modifier.background(Color.White.copy(alpha = .4f), RoundedCornerShape(20.dp)).padding(6.dp))
        Text("いつもの道に、\n新しいメロディ。", fontSize = 21.sp, lineHeight = 31.sp,
            fontWeight = FontWeight.Bold, color = MelodyColors.Ink)
        Text("すれちがうたび、好きな音が増えていく。", fontSize = 9.sp, color = Color(0xFF745887))
        HeroMelodyButton(onClick)
    }
}

@Composable
private fun HeroMelodyButton(onClick: () -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Surface(onClick = onClick, shape = shape, color = Color.Transparent,
        contentColor = Color(0xFF76558D), shadowElevation = if (pressed) 1.dp else 4.dp,
        interactionSource = source,
        modifier = Modifier.heightIn(min = 48.dp).pastelPressFeedback(source)) {
        Row(
            Modifier.background(Brush.linearGradient(listOf(Color(0xFFFFFDF3), Color(0xFFF5E9DF))))
                .border(1.dp, Color(0xFFD8C4DF), shape)
                .padding(start = 7.dp, end = 12.dp, top = 7.dp, bottom = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(Modifier.size(28.dp).clip(CircleShape)
                .background(Brush.verticalGradient(listOf(MelodyColors.Primary2, MelodyColors.Primary))),
                contentAlignment = Alignment.Center) {
                Text("♫", color = Color(0xFFFFF9EE), fontSize = 18.sp)
            }
            Text("届いたメロディ", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            Text("›", fontSize = 18.sp, color = Color(0xFFAE8ABD))
        }
    }
}

@Composable
fun PastelTabIntro(symbol: String, title: String, caption: String, metrics: List<Pair<String, String>>) {
    PastelCard {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(49.dp).clip(RoundedCornerShape(16.dp))
                    .background(Brush.verticalGradient(listOf(MelodyColors.Primary2, MelodyColors.Primary)))
                    .border(1.dp, Color.White.copy(alpha = .6f), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                    Text(symbol, fontSize = 25.sp, color = Color.White)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MelodyColors.Ink)
                    Text(caption, fontSize = 11.sp, color = MelodyColors.Muted)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                metrics.forEachIndexed { index, (label, value) ->
                    val tint = listOf(MelodyColors.Surface2, MelodyColors.Rose, MelodyColors.Honey)[index % 3]
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(17.dp))
                        .background(Brush.linearGradient(listOf(tint.copy(alpha = .7f), tint)))
                        .border(1.dp, Color.White.copy(alpha = .8f), RoundedCornerShape(17.dp)).padding(13.dp),
                        verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(label, fontSize = 9.sp, color = MelodyColors.Muted)
                        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MelodyColors.Ink)
                    }
                }
            }
        }
    }
}
