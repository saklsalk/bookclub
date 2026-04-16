export interface Profile {
  id: string;
  display_name: string;
  avatar_url: string | null;
  theme: 'classic' | 'eras' | 'romfantasy';
  created_at: string;
}

export interface Book {
  id: string;
  open_library_id: string | null;
  google_books_id: string | null;
  title: string;
  authors: string[];
  cover_url: string | null;
  page_count: number | null;
  description: string | null;
}

export interface Group {
  id: string;
  name: string;
  description: string | null;
  invite_code: string;
  cover_color: string;
  created_by: string;
  created_at: string;
}

export interface GroupMember {
  group_id: string;
  user_id: string;
  role: 'admin' | 'member';
  joined_at: string;
  profile?: Profile;
}

export interface GroupBook {
  group_id: string;
  book_id: string;
  status: 'current' | 'upcoming' | 'archived';
  added_by: string;
  started_at: string | null;
  archived_at: string | null;
  book?: Book;
}

export interface ReadingProgress {
  id: string;
  user_id: string;
  book_id: string;
  percentage: number;
  current_page: number;
  status: 'want_to_read' | 'reading' | 'finished' | 'abandoned';
  updated_at: string;
}

export interface Post {
  id: string;
  user_id: string;
  group_id: string;
  book_id: string;
  type: 'progress' | 'note' | 'milestone' | 'finished';
  body: string | null;
  percentage_at: number | null;
  page_at: number | null;
  created_at: string;
  profile?: Profile;
  reactions?: Reaction[];
}

export interface Reaction {
  post_id: string;
  user_id: string;
  emoji: string;
}

// Composed types for UI
export interface GroupWithCurrentBook extends Group {
  current_book: (GroupBook & { book: Book }) | null;
  my_progress: ReadingProgress | null;
  member_count: number;
  avg_progress: number;
}
