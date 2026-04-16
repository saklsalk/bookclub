-- =============================================
-- BookClub App — Supabase Schema
-- Privacy-first: NO email, NO PII stored
-- Run in Supabase SQL Editor
-- =============================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- TABLES
-- =============================================

-- User profiles: display name only, no email
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT NOT NULL DEFAULT 'Reader',
  avatar_url    TEXT,
  theme         TEXT DEFAULT 'classic' CHECK (theme IN ('classic', 'eras', 'romfantasy')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Global book catalog (populated via OpenLibrary / Google Books API)
CREATE TABLE public.books (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  open_library_id TEXT UNIQUE,
  google_books_id TEXT UNIQUE,
  title           TEXT NOT NULL,
  authors         TEXT[],
  cover_url       TEXT,
  page_count      INT,
  description     TEXT
);

-- Reading groups (unlimited members)
CREATE TABLE public.groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  cover_color TEXT DEFAULT '#8B4513',
  created_by  UUID REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Group membership (no member cap)
CREATE TABLE public.group_members (
  group_id  UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role      TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

-- Group's reading list: current / upcoming / archived
CREATE TABLE public.group_books (
  group_id    UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  book_id     UUID REFERENCES public.books(id),
  status      TEXT DEFAULT 'upcoming' CHECK (status IN ('current', 'upcoming', 'archived')),
  added_by    UUID REFERENCES public.profiles(id),
  started_at  TIMESTAMPTZ,
  archived_at TIMESTAMPTZ,
  PRIMARY KEY (group_id, book_id)
);

-- Global reading progress: ONE record per user+book
CREATE TABLE public.reading_progress (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  book_id      UUID REFERENCES public.books(id),
  percentage   NUMERIC(5,2) DEFAULT 0 CHECK (percentage >= 0 AND percentage <= 100),
  current_page INT DEFAULT 0,
  status       TEXT DEFAULT 'reading' CHECK (status IN ('want_to_read', 'reading', 'finished', 'abandoned')),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, book_id)
);

-- Group activity feed
-- percentage_at / page_at = reader's position at time of posting
CREATE TABLE public.posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  group_id       UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  book_id        UUID REFERENCES public.books(id),
  type           TEXT CHECK (type IN ('progress', 'note', 'milestone', 'finished')),
  body           TEXT,
  percentage_at  NUMERIC(5,2),
  page_at        INT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Emoji reactions on posts
CREATE TABLE public.reactions (
  post_id  UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id  UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji    TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_group_members_user   ON public.group_members(user_id);
CREATE INDEX idx_group_members_group  ON public.group_members(group_id);
CREATE INDEX idx_group_books_group    ON public.group_books(group_id);
CREATE INDEX idx_progress_user        ON public.reading_progress(user_id);
CREATE INDEX idx_progress_book        ON public.reading_progress(book_id);
CREATE INDEX idx_posts_group          ON public.posts(group_id, created_at DESC);
CREATE INDEX idx_posts_user           ON public.posts(user_id);

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_books     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions       ENABLE ROW LEVEL SECURITY;

-- Helper: check if current user is a member of a group
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id UUID)
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
$$;

-- Helper: check if two users share at least one group
CREATE OR REPLACE FUNCTION public.shares_group_with(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members a
    JOIN public.group_members b ON a.group_id = b.group_id
    WHERE a.user_id = auth.uid() AND b.user_id = p_user_id
  );
$$;

-- PROFILES
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (id = auth.uid() OR public.shares_group_with(id));
CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- BOOKS (readable by all authenticated users, writable by anyone — populated from API)
CREATE POLICY "books_select" ON public.books
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'anon');
CREATE POLICY "books_insert" ON public.books
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- GROUPS
CREATE POLICY "groups_select" ON public.groups
  FOR SELECT USING (public.is_group_member(id));
CREATE POLICY "groups_insert" ON public.groups
  FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "groups_update" ON public.groups
  FOR UPDATE USING (created_by = auth.uid());

-- GROUP_MEMBERS
CREATE POLICY "members_select" ON public.group_members
  FOR SELECT USING (public.is_group_member(group_id));
CREATE POLICY "members_insert" ON public.group_members
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "members_delete" ON public.group_members
  FOR DELETE USING (user_id = auth.uid());

-- GROUP_BOOKS
CREATE POLICY "group_books_select" ON public.group_books
  FOR SELECT USING (public.is_group_member(group_id));
CREATE POLICY "group_books_insert" ON public.group_books
  FOR INSERT WITH CHECK (public.is_group_member(group_id));
CREATE POLICY "group_books_update" ON public.group_books
  FOR UPDATE USING (public.is_group_member(group_id));

-- READING_PROGRESS
CREATE POLICY "progress_select" ON public.reading_progress
  FOR SELECT USING (user_id = auth.uid() OR public.shares_group_with(user_id));
CREATE POLICY "progress_insert" ON public.reading_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "progress_update" ON public.reading_progress
  FOR UPDATE USING (user_id = auth.uid());

-- POSTS
CREATE POLICY "posts_select" ON public.posts
  FOR SELECT USING (public.is_group_member(group_id));
CREATE POLICY "posts_insert" ON public.posts
  FOR INSERT WITH CHECK (user_id = auth.uid() AND public.is_group_member(group_id));
CREATE POLICY "posts_delete" ON public.posts
  FOR DELETE USING (user_id = auth.uid());

-- REACTIONS
CREATE POLICY "reactions_select" ON public.reactions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND public.is_group_member(p.group_id))
  );
CREATE POLICY "reactions_insert" ON public.reactions
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "reactions_delete" ON public.reactions
  FOR DELETE USING (user_id = auth.uid());

-- =============================================
-- RPCs
-- =============================================

-- Join a group via 6-char invite code
CREATE OR REPLACE FUNCTION public.join_group_by_code(p_invite_code TEXT)
RETURNS UUID LANGUAGE PLPGSQL SECURITY DEFINER AS $$
DECLARE
  v_group_id UUID;
BEGIN
  SELECT id INTO v_group_id
  FROM public.groups
  WHERE invite_code = UPPER(p_invite_code);

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'INVITE_NOT_FOUND';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = v_group_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'member');

  RETURN v_group_id;
END;
$$;

-- Archive a book in a group
CREATE OR REPLACE FUNCTION public.archive_group_book(p_group_id UUID, p_book_id UUID)
RETURNS VOID LANGUAGE PLPGSQL SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'NOT_ADMIN';
  END IF;

  UPDATE public.group_books
  SET status = 'archived', archived_at = NOW()
  WHERE group_id = p_group_id AND book_id = p_book_id;
END;
$$;

-- Generate a random 6-char invite code
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT LANGUAGE SQL AS $$
  SELECT UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
$$;

-- =============================================
-- TRIGGER: auto-create profile on sign up
-- NO email stored — display_name defaults to 'Reader'
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE PLPGSQL SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', 'Reader')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
