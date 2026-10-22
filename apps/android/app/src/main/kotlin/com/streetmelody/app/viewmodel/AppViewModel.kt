package com.streetmelody.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.streetmelody.app.data.model.*
import com.streetmelody.app.data.repository.MelodyRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.CancellationException

// MARK: - Navigation

sealed class Screen {
    data object Home      : Screen()
    data object Exchange  : Screen()
    data class Mystery(val trackId: String) : Screen()
    data class Puzzle(val trackId: String)  : Screen()
    data class Artist(val artistId: String) : Screen()
    data object Playlist  : Screen()
}

enum class Tab { HOME, EXCHANGE, PUZZLE, ARTIST, PLAYLIST }

// MARK: - UI State

data class HomeUiState(
    val user: User? = null,
    val collection: CollectionSummary? = null,
    val mission: Mission? = null,
    val heroTrack: Track? = null,
    val recentTracks: List<Track> = emptyList(),
)

// MARK: - AppViewModel

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val repository = MelodyRepository()

    // Nav
    private val _activeTab = MutableStateFlow(Tab.HOME)
    val activeTab: StateFlow<Tab> = _activeTab

    private val _navStack = MutableStateFlow<List<Screen>>(emptyList())
    val navStack: StateFlow<List<Screen>> = _navStack

    // Data
    private val _tracks = MutableStateFlow<Map<String, Track>>(emptyMap())
    val tracks: StateFlow<Map<String, Track>> = _tracks

    private val _encounter = MutableStateFlow<Encounter?>(null)
    val encounter: StateFlow<Encounter?> = _encounter

    private val _playlist = MutableStateFlow<DailyPlaylist?>(null)
    val playlist: StateFlow<DailyPlaylist?> = _playlist

    val homeState: StateFlow<HomeUiState> = combine(
        _tracks, _encounter, _playlist
    ) { tracks, _, playlist ->
        val heroTrackId = playlist?.tracks?.firstOrNull()?.trackId
        HomeUiState(
            heroTrack = heroTrackId?.let { tracks[it] },
            recentTracks = tracks.values.take(3).toList(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    // UI state
    private val _selectedCandidate = MutableStateFlow<Int?>(null)
    val selectedCandidate: StateFlow<Int?> = _selectedCandidate

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast

    private val _user = MutableStateFlow<User?>(null)
    val user: StateFlow<User?> = _user

    private val _collection = MutableStateFlow<CollectionSummary?>(null)
    val collection: StateFlow<CollectionSummary?> = _collection

    private val _mission = MutableStateFlow<Mission?>(null)
    val mission: StateFlow<Mission?> = _mission

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading
    private val _loadError = MutableStateFlow<String?>(null)
    val loadError: StateFlow<String?> = _loadError
    private val _actionBusy = MutableStateFlow(false)
    val actionBusy: StateFlow<Boolean> = _actionBusy
    private val preferences = app.getSharedPreferences("discovery", android.content.Context.MODE_PRIVATE)
    private val _guideFinished = MutableStateFlow(preferences.getBoolean("guide.v1", false))
    val guideFinished: StateFlow<Boolean> = _guideFinished

    fun finishGuide() {
        preferences.edit().putBoolean("guide.v1", true).apply()
        _guideFinished.value = true
    }

    fun reopenGuide() { _guideFinished.value = false }

    init { loadAll() }

    // MARK: - Load

    fun loadAll() {
        if (_loading.value) return
        _loading.value = true
        _loadError.value = null
        viewModelScope.launch {
            try {
                listOf(
                    launch { load { _user.value = repository.fetchMe() } },
                    launch { load { _collection.value = repository.fetchCollection() } },
                    launch { load { _mission.value = repository.fetchMission() } },
                    launch { load { _tracks.value = repository.fetchTracks().associateBy { it.id } } },
                    launch { load { _encounter.value = repository.fetchTodayEncounter() } },
                    launch { load { _playlist.value = repository.fetchDailyPlaylist() } },
                ).joinAll()
            } finally { _loading.value = false }
        }
    }

    private suspend fun load(block: suspend () -> Unit) {
        try { block() }
        catch (cancelled: CancellationException) { throw cancelled }
        catch (_: Exception) { _loadError.value = "一部のデータを取得できませんでした。通信を確認して再試行してください。" }
    }

    // MARK: - Actions

    fun selectCandidate(index: Int) { _selectedCandidate.value = index }

    fun confirmPiece() {
        val enc = _encounter.value ?: return
        val idx = _selectedCandidate.value ?: return
        if (idx !in enc.candidates.indices || _actionBusy.value) return
        performAction {
            val result = repository.selectPiece(enc.id, idx)
            _tracks.value = _tracks.value.toMutableMap().also { map ->
                map[result.trackId]?.let { track ->
                    if (result.added && result.pieceNumber !in track.ownedPieces) {
                        map[result.trackId] = track.copy(ownedPieces = (track.ownedPieces + result.pieceNumber).sorted())
                    }
                }
            }
            _selectedCandidate.value = null
            showToast(if (result.added) "ピースを獲得しました！" else "所持済みのピースです")
            _navStack.value = listOf(if (result.nextScreen == "puzzle") Screen.Puzzle(result.trackId) else Screen.Mystery(result.trackId))
            // Keep rewards, collection totals and the next encounter authoritative on the server.
            loadAll()
        }
    }

    private fun performAction(action: suspend () -> Unit) {
        if (_actionBusy.value) return
        _actionBusy.value = true
        viewModelScope.launch {
            try { action() }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (_: Exception) { showToast("通信に失敗しました。もう一度お試しください。") }
            finally { _actionBusy.value = false }
        }
    }

    fun applyHint(trackId: String, kind: HintKind) = performAction {
        val result = repository.applyHint(trackId, kind)
        val updated = repository.fetchTracks().associateBy { it.id }
        _tracks.value = updated.toMutableMap().also { map ->
            map[trackId]?.let { map[trackId] = it.copy(hintLevel = result.hintLevel, answerReady = result.answerReady) }
        }
        showToast("ヒントを更新しました")
    }

    fun unlockTrack(trackId: String) = performAction {
        repository.unlockTrack(trackId)
        _tracks.value = repository.fetchTracks().associateBy { it.id }
        _navStack.value = _navStack.value.dropLast(1) + Screen.Puzzle(trackId)
        showToast("曲名を解放しました！")
    }

    fun continueCollecting(trackId: String) {
        val track = _tracks.value[trackId] ?: return
        val index = collectableCandidateIndex(track, _encounter.value)
        if (index >= 0) { setTab(Tab.EXCHANGE); selectCandidate(index) }
        else openTrack(trackId)
    }

    fun openTrack(trackId: String) {
        val track = _tracks.value[trackId] ?: return
        navigate(if (track.isUnlocked) Screen.Puzzle(trackId) else Screen.Mystery(trackId))
    }

    fun navigate(screen: Screen) { _navStack.value = _navStack.value + screen }
    fun goBack()                  { _navStack.value = _navStack.value.dropLast(1) }
    fun setTab(tab: Tab)          { _activeTab.value = tab; _navStack.value = emptyList() }

    private fun showToast(msg: String) {
        _toast.value = msg
        viewModelScope.launch {
            kotlinx.coroutines.delay(2500)
            _toast.value = null
        }
    }
}

enum class HintKind { HINT1, HINT2, ANSWER }
