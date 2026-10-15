-- ─────────────────────────────────────────────────────────────
--  encounter_days にも「匿名は不可」の制限ポリシーを付ける（2026-10-15）
--
--  20261015130000 の流儀にそろえる（StreetMelody の担当セッションの指摘）。
--  この表は GRANT を外し、許可のポリシーも置いていないので、いまは誰も直接触れない。
--  それでも付けるのは、**誰かが後で許可のポリシーを1本足した日に、匿名まで通らない**
--  ようにするため。
--
--  表の GRANT は付けない（ほかの表と流儀が違うところ）。この表は送る待ち行列で、
--  直接書けると端末が sent_at（送った印）を自分で打てる。口は関数4つだけにしてある
-- ─────────────────────────────────────────────────────────────

drop policy if exists no_anon on streetmelody.encounter_days;
create policy no_anon on streetmelody.encounter_days as restrictive for all to authenticated
  using (not public.is_anon()) with check (not public.is_anon());
