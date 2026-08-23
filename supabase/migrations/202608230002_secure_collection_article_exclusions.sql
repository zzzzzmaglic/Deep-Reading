revoke insert, delete on public.collection_article_exclusions from authenticated;

drop policy if exists "owners can insert collection article exclusions"
on public.collection_article_exclusions;

drop policy if exists "owners can delete collection article exclusions"
on public.collection_article_exclusions;
