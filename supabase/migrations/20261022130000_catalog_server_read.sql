-- ─────────────────────────────────────────────────────────────
--  曲カタログをサーバー（Go・Cloud Run）が読めるようにする（2026-10-22）
--
--  サーバーは本人がいないので、秘密の鍵（sb_secret_…＝service_role）で読む。
--  service_role は RLS を越えるが、表の GRANT は要る。20261022120000 では authenticated にしか
--  渡していなかったので、サーバーが 403 になった。読むだけ（SELECT）を渡す。
-- ─────────────────────────────────────────────────────────────

grant select on streetmelody.artists, streetmelody.tracks to service_role;
