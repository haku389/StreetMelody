package com.streetmelody.app.data.model

import org.junit.Assert.*
import org.junit.Test

class DiscoveryProgressTest {
    private fun track(id: String, owned: Int, total: Int = 24) = Track(
        id = id, artistId = "artist", pieceCount = total, rewardCoins = 10,
        rewardExp = 5, color = "violet", ownedPieces = (1..owned).toList(),
    )

    @Test fun excludesUnstartedCompletedAndInvalidPuzzles() {
        val result = closestToCompletion(listOf(track("empty", 0), track("done", 24), track("invalid", 1, 0), track("near", 22)))
        assertEquals(listOf("near"), result.map { it.id })
    }

    @Test fun comparesCompletionRatioRatherThanNumberOfPieces() {
        val result = closestToCompletion(listOf(track("large", 20, 24), track("small", 11, 12)))
        assertEquals(listOf("small", "large"), result.map { it.id })
    }

    @Test fun breaksTiesDeterministicallyAndShowsAtMostTwo() {
        val result = closestToCompletion(listOf(track("c", 12), track("b", 12), track("a", 12)))
        assertEquals(listOf("a", "b"), result.map { it.id })
    }

    @Test fun lockedTrackDoesNotLeakAnAvailableTitle() {
        val locked = track("locked", 8).copy(title = "Secret title", maskedLabel = "S?????")
        assertEquals("S?????", locked.displayTitle)
        assertEquals("Secret title", locked.copy(isUnlocked = true).displayTitle)
    }

    @Test fun collectShortcutUsesOnlyAnAvailableUnownedPiece() {
        val track = track("song", 2)
        val encounter = Encounter("enc", "street", 1, "", listOf(
            Candidate("owned", "song", 1, "slot", 1, 0),
            Candidate("other", "other-song", 3, "slot", 1, 1),
            Candidate("new", "song", 3, "slot", 1, 2),
        ))
        assertEquals(2, collectableCandidateIndex(track, encounter))
        assertEquals(-1, collectableCandidateIndex(track, encounter.copy(candidates = encounter.candidates.take(2))))
        assertEquals(-1, collectableCandidateIndex(track, null))
    }

    @Test fun puzzleGridMatchesActualCatalogPieceCount() {
        assertEquals(6 to 4, puzzleGridSize(24))
        assertEquals(3 to 3, puzzleGridSize(9))
        val (columns, rows) = puzzleGridSize(10)
        assertTrue(columns * rows >= 10)
        assertEquals(1 to 1, puzzleGridSize(0))
    }
}
