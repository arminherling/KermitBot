CREATE TABLE starboard_reaction (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    channel_id INTEGER,
    message_id INTEGER,
    author_id INTEGER,
    reacted_by_id INTEGER);
