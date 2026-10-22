package com.streetmelody.app.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// StreetMelodyカラーパレット
object MelodyColors {
    val Primary    = Color(0xFFA27BC8)
    val Primary2   = Color(0xFFC3A2E4)
    val Pink       = Color(0xFFE99BB5)
    val Gold       = Color(0xFFF1CC7E)
    val Mint       = Color(0xFF7FA98A)
    val Blue       = Color(0xFF99BFDC)
    val Surface    = Color(0xFFFFF8F2)
    val Surface2   = Color(0xFFEEE0F2)
    val Ink        = Color(0xFF49335F)
    val Muted      = Color(0xFF8D7694)
    val Line       = Color(0xFFEADCE7)
    val BgGradient1 = Color(0xFFE99BB5)  // top-left
    val BgGradient2 = Color(0xFFA27BC8)  // top-right

    val Background = Color(0xFFFFF4ED)
    val Rose = Color(0xFFF6D9D7)
    val Honey = Color(0xFFF5E4C6)
    val Shadow = Color(0xFF80618B)

    // Art gradients
    val Sunset = listOf(Color(0xFFC4A7DA), Color(0xFFF0BEB9), Color(0xFFD3A6B5))
    val Violet = listOf(Color(0xFFD3C3EA), Color(0xFFB599D8), Color(0xFFA78AC5))
    val Berry  = listOf(Color(0xFFF8D6DB), Color(0xFFE8B4C5), Color(0xFFC88BA7))
    val Magic  = listOf(Color(0xFFBAD3DF), Color(0xFFC4D8B0), Color(0xFFA397CA))
    val Default = listOf(Color(0xFFC4A7DA), Color(0xFFF0BEB9), Color(0xFFB599D8))

    fun artColors(color: String) = when (color) {
        "sunset" -> Sunset
        "violet" -> Violet
        "berry"  -> Berry
        "magic"  -> Magic
        else     -> Default
    }
}

private val LightColorScheme = lightColorScheme(
    primary         = MelodyColors.Primary,
    secondary       = MelodyColors.Pink,
    tertiary        = MelodyColors.Gold,
    background      = MelodyColors.Background,
    surface         = MelodyColors.Surface,
    onPrimary       = Color.White,
    onBackground    = MelodyColors.Ink,
    onSurface       = MelodyColors.Ink,
    onSurfaceVariant = MelodyColors.Muted,
    surfaceVariant = MelodyColors.Surface2,
    primaryContainer = MelodyColors.Surface2,
    onPrimaryContainer = MelodyColors.Ink,
    outline = MelodyColors.Line,
)

@Composable
fun StreetMelodyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography(),
        content = content
    )
}
