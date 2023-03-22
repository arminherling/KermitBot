CREATE TABLE chat_context (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER UNIQUE,
    text TEXT);
