CREATE TABLE starboard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    star_count INTEGER,
    message_id INTEGER UNIQUE,
    channel_id INTEGER,
    server_id INTEGER,
    starboard_message_id INTEGER,
    content TEXT,
    message_timestamp TEXT,
    author_name TEXT,
    author_icon TEXT,
    embed_image_url TEXT,
    jump_link TEXT,
    attachment_link TEXT);
