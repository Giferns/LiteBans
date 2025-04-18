const MAX_REASON_LENGTH = 96;

forward lite_bans_sql_init(Handle:hSqlTuple);

forward user_banned_pre(banned_id, admin_id, ban_minutes, const ban_reason[MAX_REASON_LENGTH]);