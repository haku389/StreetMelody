package main

import (
	"fmt"
	"net/http"
	"os"

	"streetmelody/api/handler"
	"streetmelody/api/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	s := store.New()

	// Supabase からカタログ取得（失敗時は埋め込みシードで継続）
	sbURL := os.Getenv("SUPABASE_URL")
	if sbURL == "" {
		sbURL = store.DefaultSupabaseURL
	}
	// カタログはログインした人だけが読める（アプリはログイン必須）。サーバーには本人がいないので、
	// 読むにはサーバー用の秘密の鍵（SUPABASE_SECRET_KEY）が要る。無ければ公開キーで試し、
	// 読めなければ埋め込みの見本で動く
	sbKey := os.Getenv("SUPABASE_SECRET_KEY")
	if sbKey == "" {
		sbKey = os.Getenv("SUPABASE_ANON_KEY")
	}
	if sbKey == "" {
		sbKey = store.DefaultSupabaseAnonKey
	}
	sbSchema := os.Getenv("SUPABASE_SCHEMA")
	if sbSchema == "" {
		sbSchema = store.DefaultSupabaseSchema
	}
	if err := s.LoadFromSupabase(sbURL, sbKey, sbSchema); err != nil {
		fmt.Fprintf(os.Stderr, "supabase unavailable, using embedded seed: %v\n", err)
	} else {
		fmt.Println("catalog loaded from Supabase:", sbURL, "schema:", sbSchema)
	}

	h := handler.New(s)

	mux := http.NewServeMux()
	mux.Handle("/api/", h)

	addr := ":" + port
	fmt.Printf("StreetMelody API listening on http://localhost%s\n", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
