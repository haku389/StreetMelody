package store

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// カタログは public ではなく streetmelody スキーマにあるので、
// Accept-Profile を付けずに読むと PostgREST は public を探して 404 になる
func TestLoadFromSupabaseAsksForSchema(t *testing.T) {
	var profiles []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		profiles = append(profiles, r.Header.Get("Accept-Profile"))
		if r.Header.Get("Accept-Profile") != "streetmelody" {
			http.Error(w, `{"code":"PGRST205"}`, http.StatusNotFound)
			return
		}
		switch r.URL.Path {
		case "/rest/v1/artists":
			json.NewEncoder(w).Encode([]supabaseArtist{{ID: "artist_higedan", Name: "Official髭男dism"}})
		case "/rest/v1/tracks":
			json.NewEncoder(w).Encode([]supabaseTrack{{
				ID: "track_pretender", ArtistID: "artist_higedan", Title: "Pretender",
				YoutubeVideoID: "TQ8WlA2GXbk", PieceCount: 24, Color: "magic",
				ThumbnailURL: "https://i.ytimg.com/vi/TQ8WlA2GXbk/maxresdefault.jpg",
			}})
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	s := New()
	if err := s.LoadFromSupabase(srv.URL, "key", "streetmelody"); err != nil {
		t.Fatalf("load: %v (profiles=%v)", err, profiles)
	}
	got, ok := s.trackMap["track_pretender"]
	if !ok {
		t.Fatalf("track_pretender was not loaded")
	}
	if got.PieceCount != 24 || got.ThumbnailURL == "" {
		t.Fatalf("unexpected track: %+v", got)
	}

	// スキーマを渡さないと、public を読みに行って失敗する（埋め込みの見本のまま動く）
	if err := New().LoadFromSupabase(srv.URL, "key", ""); err == nil {
		t.Fatalf("expected an error without the schema")
	}
}
