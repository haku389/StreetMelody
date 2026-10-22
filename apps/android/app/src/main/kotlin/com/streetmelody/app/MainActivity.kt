package com.streetmelody.app

import android.os.Bundle
import androidx.activity.compose.BackHandler
import com.streetmelody.app.viewmodel.Screen
import com.streetmelody.app.ui.discovery.*
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.layout.ContentScale
import com.streetmelody.app.ui.components.PastelCard
import com.streetmelody.app.ui.components.PastelButton
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import com.streetmelody.app.ui.theme.MelodyColors
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import com.streetmelody.app.ui.home.HomeScreen
import com.streetmelody.app.ui.puzzle.PuzzleScreen
import com.streetmelody.app.ui.theme.StreetMelodyTheme
import com.streetmelody.app.viewmodel.AppViewModel
import com.streetmelody.app.viewmodel.Tab

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            StreetMelodyTheme {
                StreetMelodyApp(vm = vm)
            }
        }
    }
}

@Composable
fun StreetMelodyApp(vm: AppViewModel) {
    val activeTab by vm.activeTab.collectAsState()
    val toast by vm.toast.collectAsState()
    val stack by vm.navStack.collectAsState()
    val loading by vm.loading.collectAsState()
    val loadError by vm.loadError.collectAsState()
    BackHandler(enabled = stack.isNotEmpty()) { vm.goBack() }

    Scaffold(
        containerColor = MelodyColors.Background,
        contentColor = MelodyColors.Ink,
        bottomBar = { BottomNavBar(activeTab = activeTab, onTabSelected = vm::setTab) }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding).background(
            Brush.verticalGradient(listOf(MelodyColors.Surface, MelodyColors.Background, Color(0xFFF5EAF2)))
        )) {
            Column(Modifier.fillMaxSize()) {
                if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                if (loadError != null) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(loadError!!, fontSize = 11.sp, color = MelodyColors.Muted, modifier = Modifier.weight(1f))
                    TextButton(onClick = vm::loadAll, enabled = !loading) { Text("再試行") }
                }
                if (stack.isNotEmpty()) TextButton(onClick = vm::goBack) { Text("‹ 戻る") }
                Box(Modifier.weight(1f)) {
                    when (val screen = stack.lastOrNull()) {
                        is Screen.Puzzle -> PuzzleScreen(vm, screen.trackId)
                        is Screen.Mystery -> MysteryScreen(vm, screen.trackId)
                        is Screen.Artist -> ArtistScreen(vm, screen.artistId)
                        Screen.Playlist -> PlaylistScreen(vm)
                        Screen.Exchange -> ExchangeScreen(vm)
                        else -> when (activeTab) {
                            Tab.HOME -> HomeScreen(vm)
                            Tab.EXCHANGE -> ExchangeScreen(vm)
                            Tab.PUZZLE -> CollectionScreen(vm)
                            Tab.ARTIST -> ArtistScreen(vm)
                            Tab.PLAYLIST -> PlaylistScreen(vm)
                        }
                    }
                }
            }

            // Toast
            if (toast != null) {
                Surface(
                    modifier = Modifier.align(Alignment.BottomCenter),
                    shape = MaterialTheme.shapes.extraLarge,
                    shadowElevation = 8.dp,
                ) {
                    Text(toast!!, modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
private fun BottomNavBar(activeTab: Tab, onTabSelected: (Tab) -> Unit) {
    val items = listOf(
        Triple(Tab.HOME,     "home",         "ホーム"),
        Triple(Tab.EXCHANGE, "swap_horiz",   "届いた"),
        Triple(Tab.PUZZLE,   "extension",    "パズル"),
        Triple(Tab.ARTIST,   "star",         "アーティスト"),
        Triple(Tab.PLAYLIST, "queue_music",  "プレイリスト"),
    )
    NavigationBar(
        modifier = Modifier.navigationBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp)
            .shadow(8.dp, RoundedCornerShape(24.dp), ambientColor = MelodyColors.Shadow.copy(alpha = .2f), spotColor = MelodyColors.Shadow.copy(alpha = .2f))
            .clip(RoundedCornerShape(24.dp))
            .border(1.dp, Color.White, RoundedCornerShape(24.dp)),
        containerColor = MelodyColors.Surface,
        tonalElevation = 0.dp,
        windowInsets = WindowInsets(0, 0, 0, 0),
    ) {
        items.forEach { (tab, _, label) ->
            NavigationBarItem(
                selected = activeTab == tab,
                onClick  = { onTabSelected(tab) },
                icon     = { Text(tabEmoji(tab), fontSize = 23.sp, fontWeight = FontWeight.SemiBold) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = MelodyColors.Primary,
                    selectedTextColor = MelodyColors.Ink,
                    indicatorColor = MelodyColors.Surface2,
                    unselectedIconColor = MelodyColors.Muted,
                    unselectedTextColor = MelodyColors.Muted,
                ),
                label    = { Text(label, style = MaterialTheme.typography.labelSmall) },
            )
        }
    }
}

private fun tabEmoji(tab: Tab) = when (tab) {
    Tab.HOME     -> "⌂"
    Tab.EXCHANGE -> "⇄"
    Tab.PUZZLE   -> "◈"
    Tab.ARTIST   -> "☆"
    Tab.PLAYLIST -> "♫"
}
