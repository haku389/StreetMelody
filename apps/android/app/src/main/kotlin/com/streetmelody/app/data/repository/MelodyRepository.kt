package com.streetmelody.app.data.repository

import com.streetmelody.app.BuildConfig
import com.streetmelody.app.data.model.*
import com.streetmelody.app.viewmodel.HintKind
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class MelodyRepository {

    private val client = HttpClient(Android) {
        expectSuccess = true
        install(HttpTimeout) { requestTimeoutMillis = 12_000; connectTimeoutMillis = 8_000 }
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; coerceInputValues = true })
        }
    }

    private val base = BuildConfig.API_BASE_URL

    // MARK: - User

    suspend fun fetchMe():         User              = client.get("$base/me").body()
    suspend fun fetchCollection(): CollectionSummary = client.get("$base/me/collection").body()
    suspend fun fetchMission():    Mission           = client.get("$base/me/mission").body()

    // MARK: - Tracks

    suspend fun fetchTracks(): List<Track> = client.get("$base/tracks").body()

    suspend fun unlockTrack(trackId: String) {
        client.post("$base/tracks/$trackId/unlock")
    }

    suspend fun applyHint(trackId: String, kind: HintKind): HintResponse {
        val kindStr = when (kind) {
            HintKind.HINT1  -> "hint1"
            HintKind.HINT2  -> "hint2"
            HintKind.ANSWER -> "answer"
        }
        return client.post("$base/tracks/$trackId/hint") {
            contentType(ContentType.Application.Json)
            setBody(HintBody(kindStr))
        }.body()
    }

    suspend fun addListenLater(trackId: String) {
        client.post("$base/tracks/$trackId/listen-later")
    }

    // MARK: - Encounter

    suspend fun fetchTodayEncounter(): Encounter = client.get("$base/encounters/today").body()

    suspend fun selectPiece(encounterId: String, candidateIndex: Int): SelectPieceResponse =
        client.post("$base/encounters/$encounterId/select") {
            contentType(ContentType.Application.Json)
            setBody(SelectBody(candidateIndex))
        }.body()

    // MARK: - Playlist

    suspend fun fetchDailyPlaylist(): DailyPlaylist = client.get("$base/playlist/daily").body()
}

@Serializable private data class HintBody(val kind: String)
@Serializable private data class SelectBody(val candidateIndex: Int)
