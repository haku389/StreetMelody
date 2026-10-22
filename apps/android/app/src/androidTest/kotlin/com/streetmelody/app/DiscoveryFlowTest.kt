package com.streetmelody.app

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Integration smoke test against an isolated local API on the emulator host (port 3001). */
@RunWith(AndroidJUnit4::class)
class DiscoveryFlowTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun tab(label: String) {
        compose.onAllNodes(hasText(label) and hasClickAction()).onFirst().performClick()
    }

    private fun preview(name: String) {
        compose.waitForIdle()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val folder = File(InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")
            ?: instrumentation.targetContext.getExternalFilesDir(null)!!.absolutePath)
        folder.mkdirs()
        val bitmap = instrumentation.uiAutomation.takeScreenshot()
        File(folder, "tabs-$name-android.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    @Test fun heldHeroShowsFeedbackAndCancellationDoesNotNavigate() {
        val hero = compose.onNode(hasText("届いたメロディ", substring = false) and hasClickAction())
        hero.performScrollTo().assertIsDisplayed()
        preview("press-resting")
        val resting = hero.captureToImage().asAndroidBitmap()
        hero.performTouchInput { down(center) }
        // Keep the finger down after the scroll container's press delay and the feedback animation.
        compose.mainClock.advanceTimeBy(1_500)
        compose.onNodeWithText("いつもの道に、\n新しいメロディ。").assertExists()
        val held = hero.captureToImage().asAndroidBitmap()
        org.junit.Assert.assertFalse("Holding must visibly change the button", resting.sameAs(held))
        preview("press-held")
        hero.performTouchInput { cancel() }
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("いつもの道に、\n新しいメロディ。").assertExists()
        preview("press-restored")
        hero.performClick()
        compose.onNodeWithText("気になる曲を選んで、ピースを1枚受け取ろう。").assertExists()
    }

    @Test fun receivePieceThenExploreArtistPlaylistAndCollection() {
        compose.waitUntil(15_000) { compose.onAllNodesWithText("次へ").fetchSemanticsNodes().isNotEmpty() || compose.onAllNodesWithText("はじめての方へ · 使い方を見る").fetchSemanticsNodes().isNotEmpty() }
        if (compose.onAllNodesWithText("あとで").fetchSemanticsNodes().isNotEmpty()) compose.onNodeWithText("あとで").performClick()
        tab("届いた")
        compose.waitUntil(15_000) { compose.onAllNodes(hasClickAction() and hasText("（未所持）", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onAllNodes(hasClickAction() and hasText("（未所持）", substring = true)).onFirst().performScrollTo().performClick()
        preview("exchange")
        compose.onNodeWithText("このピースを受け取る").performScrollTo().performClick()
        compose.onNodeWithText("受け取る", substring = false).performClick()
        compose.waitUntil(15_000) { compose.onAllNodesWithText("‹ 戻る").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("‹ 戻る").assertIsDisplayed()
        tab("アーティスト")
        compose.waitUntil(15_000) { compose.onAllNodes(hasClickAction() and hasText(" ピース", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        preview("artists")
        compose.onAllNodes(hasClickAction() and hasText(" ピース", substring = true)).onFirst().performClick()
        compose.onNodeWithText("‹ 戻る").assertIsDisplayed()
        tab("プレイリスト")
        compose.onNodeWithText("すれちがいから届いた音を、もう一度。").assertIsDisplayed()
        preview("playlist")
        tab("パズル")
        compose.onNodeWithText("集めたピースから、好きな曲を増やそう。").assertIsDisplayed()
        preview("collection")
        tab("ホーム")
        compose.waitUntil(15_000) { compose.onAllNodesWithText("あと少しで完成").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("あと少しで完成").assertExists()
    }
}
