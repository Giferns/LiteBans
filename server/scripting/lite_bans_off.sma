/*
	1.6: add kicks counter in WEB
	1.7: add unban menu
	1.7.1: fix бана
	1.7.2: fix анбана
	1.7.3: fix анбана
	1.8: убран лишний запрос в базу
	1.9: ренейм квара lb_full_access и superadmin для бана/разбана
	2.0: add offline ban menu
	2.1: maybe fix console info :D
	2.2: фикс цвета HUD'a
*/

/* История обновлений:
	2.3f (20.07.2023):
		* Убрана поддержка amxx ниже 190
		* Фикс компиляции на amxx 190+
		* Форварду user_banned_pre() добавлены аргументы admin_id и ban_minutes
		* Фикс повторного бана уже забаненного игрока (пока в самом простом неинтуитивном варианте)
*/

new const PLUGIN_VERSION[] = "2.3f";

#include <amxmodx>
#include <time>
#include <sqlx>

const MAX_REASON_LENGTH = 96;

enum _:global_cvars
{
	srv_name[64],
	srv_ip[24],
	cookie_link[128],
	hud_msg[512],
	hud_msg_color[3],
	superadmin,
	global_bans,
	ip_bantime,
	static_reasons,
	static_time
};
enum _:BanData
{
	index,
	bantime,
	reason[MAX_REASON_LENGTH]
};
enum _:OffData
{
	name[MAX_NAME_LENGTH],
	ip[16],
	authid[MAX_AUTHID_LENGTH],
	immunity
};
enum _:KickData
{
	auth[MAX_AUTHID_LENGTH],
	u_name[MAX_NAME_LENGTH],
	a_name[MAX_NAME_LENGTH],
	ban_reason[MAX_REASON_LENGTH],
	ban_time,
	ban_length,
	bid
};
enum _:PlrData
{
	bool:cookie,
	pstate
};
enum
{
	none,
	checked,
	ban,
};
enum _:
{
	Ban,
	Unban,
	UnbanMenu,
	OffbanMenu,
	Check,
	Search,
	Expired,
	Update,
	AddServer,
	GetServer
};

enum fwd
{
	SqlInit,
	PreBan
};
enum CVARS
{
	host,
	user,
	pass,
	db,
	pref,
	delay,
	srvname,
	srvip,
	allbans,
	ipban,
	reasons,
	rsnbtm,
	crsn,
	rmvexp,
	sadmin,
	unbanm,
	lnkck,
	hud,
	hudpos,
	hudclr
};

new Handle:g_hSqlTuple,
	g_Data[2],
	g_szTablePrefix[64],
	szQuery[1024];

new g_playerData[MAX_PLAYERS + 1][PlrData];
new g_arrBanData[MAX_PLAYERS + 1][BanData];
new g_arrKickData[MAX_PLAYERS + 1][KickData];

new g_iTimeMenu, g_iReasonMenu;

new g_fwdHandle[fwd];

new g_pCvars[CVARS],
	g_Cvars[global_cvars];

new Float:g_fHudPos[2];

new g_szConfigDir[64];

new Array:g_aOffPlayers, g_arrOffPlayers[OffData];
#define MAX_STRINGS 20
new g_iStrings;
new g_szConsole[MAX_STRINGS][256];

new g_bBanned[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Lite Bans", PLUGIN_VERSION, "neygomon + mx?!");
	register_dictionary("lite_bans.txt");

	register_message(get_user_msgid("MOTD"), "CheckCookies");

	register_clcmd("banreason", "clcmdBanReason", 	ADMIN_BAN);
	register_clcmd("amx_banmenu", "clcmdBanMenu", 	ADMIN_BAN);
	register_clcmd("amx_offbanmenu", "clcmdOffBanMenu", ADMIN_BAN);
	register_clcmd("amx_unbanmenu", "clcmdUnBanMenu", ADMIN_BAN);

	register_concmd("amx_ban",  "concmdBan",	ADMIN_BAN);
	register_concmd("amx_unban","concmdUnBan",   	ADMIN_BAN);
	register_concmd("find_ban", "concmdFindBan", 	ADMIN_BAN);

	g_pCvars[host] = register_cvar("lb_sql_host", 	"127.0.0.1");
	g_pCvars[user] = register_cvar("lb_sql_user", 	"root",	    FCVAR_PROTECTED);
	g_pCvars[pass] = register_cvar("lb_sql_pass", 	"password", FCVAR_PROTECTED);
	g_pCvars[db]   = register_cvar("lb_sql_db",   	"database");
	g_pCvars[pref] = register_cvar("lb_sql_pref", 	"amx");

	g_pCvars[delay]  = register_cvar("lb_kick_delay", 	"3");
	g_pCvars[allbans]= register_cvar("lb_all_bans",   	"1");
	g_pCvars[ipban]	 = register_cvar("lb_ip_bantime",   	"60");
	g_pCvars[reasons]= register_cvar("lb_static_reason",   	"1");
	g_pCvars[rsnbtm] = register_cvar("lb_static_bantime",   "1");
	g_pCvars[crsn]   = register_cvar("lb_custom_reason",   	"1");
	g_pCvars[rmvexp] = register_cvar("lb_remove_expired",   "1");
	g_pCvars[sadmin] = register_cvar("lb_full_access",   	"l");
	g_pCvars[unbanm] = register_cvar("lb_unban_max_list",	"10");
	g_pCvars[lnkck]  = register_cvar("lb_link_to_banphp",   "");
	g_pCvars[srvname]= register_cvar("lb_server_name",	"Half-Life");
	g_pCvars[srvip]	 = register_cvar("lb_server_ip",  	"127.0.0.1:27015");

	g_pCvars[hud] 	 = register_cvar("lb_hud_text",  	"");
	g_pCvars[hudpos] = register_cvar("lb_hud_pos",  	"0.05 0.30");
	g_pCvars[hudclr] = register_cvar("lb_hud_color",  	"0 255 0");

	g_fwdHandle[PreBan]  = CreateMultiForward("user_banned_pre", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_fwdHandle[SqlInit]  = CreateMultiForward("lite_bans_sql_init", ET_IGNORE, FP_CELL);

	LoadCvars();
}

public plugin_cfg()
{
	g_aOffPlayers = ArrayCreate(OffData);

	new str[190];
	formatex(str, charsmax(str), "%L", LANG_SERVER, "TIMEMENU_TITLE");
	g_iTimeMenu 	= menu_create(str, "TimeMenuHandler");
	formatex(str, charsmax(str), "%L", LANG_SERVER, "REASONMENU_TITLE");
	g_iReasonMenu 	= menu_create(str, "ReasonMenuHandler");
#define TEST
#if defined TEST
	new iLen = formatex(szQuery, charsmax(szQuery), "SELECT `id` FROM `%s_serverinfo` WHERE `address` = '%s';", g_szTablePrefix, g_Cvars[srv_ip]);
	if(get_pcvar_num(g_pCvars[rmvexp]))
		formatex(szQuery[iLen], charsmax(szQuery) - iLen, "DELETE FROM `%s_bans` WHERE ((`ban_created` + `ban_length` * 60) < UNIX_TIMESTAMP(NOW())) AND `ban_length` > '0'", g_szTablePrefix);
	else	formatex(szQuery[iLen], charsmax(szQuery) - iLen, "UPDATE `%s_bans` SET `expired` = '1' WHERE ((`ban_created` + `ban_length` * 60) < UNIX_TIMESTAMP(NOW())) AND `ban_length` > '0'", g_szTablePrefix);

	g_Data[0] = GetServer;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
#else
	if(get_pcvar_num(g_pCvars[rmvexp]))
		formatex(szQuery, charsmax(szQuery), "DELETE FROM `%s_bans` WHERE ((`ban_created` + `ban_length` * 60) < UNIX_TIMESTAMP(NOW())) AND `ban_length` > '0'", g_szTablePrefix);
	else	formatex(szQuery, charsmax(szQuery), "UPDATE `%s_bans` SET `expired` = '1' WHERE ((`ban_created` + `ban_length` * 60) < UNIX_TIMESTAMP(NOW())) AND `ban_length` > '0'", g_szTablePrefix);

	g_Data[0] = Expired;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));

	formatex(szQuery, charsmax(szQuery), "SELECT `id` FROM `%s_serverinfo` WHERE `address` = '%s'", g_szTablePrefix, g_Cvars[srv_ip]);

	g_Data[0] = GetServer;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
#endif
	LoadConfigs();
}

public plugin_end()
{
	SQL_FreeHandle(g_hSqlTuple);
	ArrayDestroy(g_aOffPlayers);
}

public client_putinserver(id)
{
	g_playerData[id][cookie] = false;
	g_playerData[id][pstate] = none;

	set_task(3.0, "CheckBan", id);
}

public client_remove(id)
{
	g_bBanned[id] = false;
}

public client_disconnected(id)
{
	get_user_name(id, g_arrOffPlayers[name], charsmax(g_arrOffPlayers[name]));
	get_user_ip(id, g_arrOffPlayers[ip], charsmax(g_arrOffPlayers[ip]), 1);
	get_user_authid(id, g_arrOffPlayers[authid], charsmax(g_arrOffPlayers[authid]));
	g_arrOffPlayers[immunity] = (get_user_flags(id) & ADMIN_IMMUNITY);

	for(new i, aSize = ArraySize(g_aOffPlayers), arrOff[OffData]; i < aSize; ++i)
	{
		ArrayGetArray(g_aOffPlayers, i, arrOff);

		// if(strcmp(g_arrOffPlayers[authid], arrOff[authid]) == 0 || strcmp(g_arrOffPlayers[ip], arrOff[ip]) == 0)
		if(strcmp(g_arrOffPlayers[authid], arrOff[authid]) == 0)
			return;
	}

	ArrayPushArray(g_aOffPlayers, g_arrOffPlayers);
}

public clcmdBanMenu(id, flags)
{
	if(!CmdAccess(id, flags))
		return PLUGIN_HANDLED;

	new str[190];
	formatex(str, charsmax(str), "%L", LANG_SERVER, "BANMENU_TITLE");
	new menu = menu_create(str, "BanMenuHandler");
	new pl[MAX_PLAYERS], pnum;
	get_players(pl, pnum, "c");

	if(get_user_flags(id) & g_Cvars[superadmin])
	{
		for(new i, pid[3], szName[MAX_NAME_LENGTH]; i < pnum; i++)
		{
			if(id == pl[i])
				continue;

			get_user_name(pl[i], szName, charsmax(szName));
			pid[0] = pl[i]; menu_additem(menu, szName, pid);
		}
	}
	else
	{
		for(new i, pid[3], szName[MAX_NAME_LENGTH]; i < pnum; i++)
		{
		/*
			if(id == pl[i])
				continue;
		*/
			if(get_user_flags(pl[i]) & ADMIN_IMMUNITY)
				continue;

			get_user_name(pl[i], szName, charsmax(szName));
			pid[0] = pl[i]; menu_additem(menu, szName, pid);
		}
	}

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public clcmdOffBanMenu(id, flags)
{
	if(!CmdAccess(id, flags))
		return PLUGIN_HANDLED;

	new str[190];
	formatex(str, charsmax(str), "%L", LANG_SERVER, "OFFMENU_TITLE");
	new menu = menu_create(str, "OffMenuHandler");
	new szAuth[MAX_AUTHID_LENGTH]; get_user_authid(id, szAuth, charsmax(szAuth));

	if(get_user_flags(id) & g_Cvars[superadmin])
	{
		for(new i, pid[3], aSize = ArraySize(g_aOffPlayers); i < aSize; ++i)
		{
			ArrayGetArray(g_aOffPlayers, i, g_arrOffPlayers);

			if(strcmp(szAuth, g_arrOffPlayers[authid]) == 0)
				continue;

			pid[0] = i; menu_additem(menu, g_arrOffPlayers[name], pid);
		}
	}
	else
	{
		for(new i, pid[3], aSize = ArraySize(g_aOffPlayers); i < aSize; ++i)
		{
			ArrayGetArray(g_aOffPlayers, i, g_arrOffPlayers);

			if(g_arrOffPlayers[immunity])
				continue;
			if(strcmp(szAuth, g_arrOffPlayers[authid]) == 0)
				continue;

			pid[0] = i; menu_additem(menu, g_arrOffPlayers[name], pid);
		}
	}

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public clcmdUnBanMenu(id, flags)
{
	if(!CmdAccess(id, flags))
		return PLUGIN_HANDLED;

	new flags[2];
	get_pcvar_string(g_pCvars[sadmin], flags, charsmax(flags));

	if(get_user_flags(id) & g_Cvars[superadmin])
		formatex(szQuery, charsmax(szQuery),
			"SELECT `bid`, `player_nick`, `admin_nick` FROM `%s_bans` WHERE `expired` = '0' ORDER BY `bid` DESC LIMIT 0, %d",
				g_szTablePrefix, get_pcvar_num(g_pCvars[unbanm])
		);
	else
	{
		new admin_authid[MAX_AUTHID_LENGTH];
		get_user_authid(id, admin_authid, charsmax(admin_authid));
		formatex(szQuery, charsmax(szQuery),
			"SELECT `bid`, `player_nick` FROM `%s_bans` WHERE `expired` = '0' AND `admin_id` = '%s' ORDER BY `bid` DESC LIMIT 0, %d",
				g_szTablePrefix,
				admin_authid,
				get_pcvar_num(g_pCvars[unbanm])
		);
	}

	g_Data[0] = UnbanMenu;
	g_Data[1] = id;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
	return PLUGIN_HANDLED;
}

public BanMenuHandler(id, menu, item)
	return MenusHandler(id, menu, item, 1);

public TimeMenuHandler(id, menu, item)
	return MenusHandler(id, menu, item, 2);

public ReasonMenuHandler(id, menu, item)
	return MenusHandler(id, menu, item, 3);

public UnBanMenuHandler(id, menu, item)
	return MenusHandler(id, menu, item, 4);

public OffMenuHandler(id, menu, item)
	return MenusHandler(id, menu, item, 5);

public clcmdBanReason(id, flags)
{
	if(!CmdAccess(id, flags))
		return UTIL_console_print(id, "%L", id, "ACCESS_DENIED_CNSL");
	if(g_arrBanData[id][index])
	{
		read_argv(1, g_arrBanData[id][reason], charsmax(g_arrBanData[][reason]));

		if(g_arrBanData[id][index] > 32)
			OffBanAction(id, g_arrBanData[id][index] - 33);
		else 	BanAction(id, g_arrBanData[id][index]);
	}
	return PLUGIN_HANDLED;
}

public concmdBan(id, flags)
{
	if(!CmdAccess(id, flags))
		return UTIL_console_print(id, "%L", id, "ACCESS_DENIED_CNSL");
	if(read_argc() < 4)
		return UTIL_console_print(id, "%L", id, "AMX_BAN_SYNTAX_CNSL");
	new szTime[10], szTarget[MAX_NAME_LENGTH];
	read_argv(1, szTime, charsmax(szTime));
	read_argv(2, szTarget, charsmax(szTarget));
	read_argv(3, g_arrBanData[id][reason], charsmax(g_arrBanData[][reason]));

	g_arrBanData[id][bantime] = str_to_num(szTime);
	g_arrBanData[id][index]   = cmd_target(id, szTarget);

	if(g_arrBanData[id][index])
	{
		switch(g_playerData[g_arrBanData[id][index]][pstate])
		{
			case checked: 	BanAction(id, g_arrBanData[id][index]);
			case none: 	g_playerData[g_arrBanData[id][index]][pstate] = ban;
		}
	}
	return PLUGIN_HANDLED;
}

public concmdUnBan(id, flags)
{
	if(!CmdAccess(id, flags))
		return UTIL_console_print(id, "%L", id, "ACCESS_DENIED_CNSL");
	if(read_argc() < 2)
		return UTIL_console_print(id, "%L", id, "AMX_UNBAN_SYNTAX_CNSL");

	new szTarget[MAX_NAME_LENGTH]; read_argv(1, szTarget, charsmax(szTarget));

	if(get_user_flags(id) & g_Cvars[superadmin])
	{
		if(get_pcvar_num(g_pCvars[rmvexp]))
			formatex(szQuery, charsmax(szQuery),
				"DELETE FROM `%s_bans` WHERE `player_id` = '%s' OR `player_nick` = '%s'",
			g_szTablePrefix, szTarget, szTarget);
		else
			formatex(szQuery, charsmax(szQuery),
				"UPDATE `%s_bans` SET `expired` = '1' WHERE `player_id` = '%s' OR `player_nick` = '%s'",
			g_szTablePrefix, szTarget, szTarget);
	}
	else
	{
		new admin_authid[MAX_AUTHID_LENGTH];
		get_user_authid(id, admin_authid, charsmax(admin_authid));

		if(get_pcvar_num(g_pCvars[rmvexp]))
			formatex(szQuery, charsmax(szQuery),
				"DELETE FROM `%s_bans` WHERE `admin_id` = '%s' AND (`player_id` = '%s' OR `player_nick` = '%s')",
			g_szTablePrefix, admin_authid, szTarget, szTarget);
		else
			formatex(szQuery, charsmax(szQuery),
				"UPDATE `%s_bans` SET `expired` = '1' WHERE `admin_id` = '%s' AND (`player_id` = '%s' OR `player_nick` = '%s')",
			g_szTablePrefix, admin_authid, szTarget, szTarget);
	}

	g_Data[0] = Unban;
	g_Data[1] = id;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
	return PLUGIN_HANDLED;
}

public concmdFindBan(id, flags)
{
	if(!CmdAccess(id, flags))
		return UTIL_console_print(id, "%L", id, "ACCESS_DENIED_CNSL");
	if(read_argc() < 3)
		UTIL_console_print(id, "%L", id, "FIND_BAN_SYNTAX_CNSL");
	else
	{
		new szSearch[MAX_NAME_LENGTH], szPage[5];
		read_argv(1, szSearch, charsmax(szSearch));
		read_argv(2, szPage, charsmax(szPage));

		new iPage = str_to_num(szPage);
		new iLimit = (iPage > 1) ? iPage * 10 : 0;
		if(iLimit > 100) iLimit = 100;

		formatex(szQuery, charsmax(szQuery),
			"SELECT `player_nick`, `player_id`, `admin_nick`, `ban_reason`, `ban_created`, `ban_length` FROM `%s_bans` \
				WHERE `expired` = '0' AND (`player_id` REGEXP '^^.*%s*' OR `player_nick` REGEXP '^^.*%s*') LIMIT %d, 10",
		g_szTablePrefix, szSearch, szSearch, iLimit);

		g_Data[0] = Search;
		g_Data[1] = id;
		SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
	}
	return PLUGIN_HANDLED;
}

public CheckCookies(msgId, msgDes, msgEnt)
{
	if(g_playerData[msgEnt][cookie])
		return PLUGIN_CONTINUE;
	else if(g_Cvars[cookie_link][0])
	{
		static szBuffer[190], szAuth[MAX_AUTHID_LENGTH];
		get_user_authid(msgEnt, szAuth, charsmax(szAuth));
		formatex(szBuffer, charsmax(szBuffer), "%s?check=1&steam=%s", g_Cvars[cookie_link], szAuth);
		show_motd(msgEnt, szBuffer, "Counter-Strike 1.6 Server");
	}
	else 	CheckBan(msgEnt);

	g_playerData[msgEnt][cookie] = true;
	return PLUGIN_HANDLED;
}

public CheckBan(id)
{
	if(!is_user_connected(id))
		return;
	else	remove_task(id);

	new szIP[16], szAuth[MAX_AUTHID_LENGTH];
	get_user_ip(id, szIP, charsmax(szIP), 1);
	get_user_authid(id, szAuth, charsmax(szAuth));

	if(g_Cvars[global_bans])
		formatex(szQuery, charsmax(szQuery),
			"SELECT `player_id`, `player_nick`, `admin_nick`, `ban_reason`, `ban_created`, `ban_length` FROM `%s_bans` \
				WHERE ((`ban_created` + `ban_length` * 60) > UNIX_TIMESTAMP(NOW()) OR `ban_length` = '0') \
					AND ((`player_ip` = '%s' AND UNIX_TIMESTAMP(NOW()) - `ban_created` < '%d') OR `player_id` = '%s') AND `expired` = '0'",
		g_szTablePrefix, szIP, g_Cvars[ip_bantime], szAuth);
	else	formatex(szQuery, charsmax(szQuery),
			"SELECT `player_id`, `player_nick`, `admin_nick`, `ban_reason`, `ban_created`, `ban_length` FROM `%s_bans` \
				WHERE `server_ip` = '%s' AND ((`ban_created` + `ban_length` * 60) > UNIX_TIMESTAMP(NOW()) OR `ban_length` = '0') \
					AND ((`player_ip` = '%s' AND UNIX_TIMESTAMP(NOW()) - `ban_created` < '%d') OR `player_id` = '%s') AND `expired` = '0'",
		g_szTablePrefix, g_Cvars[srv_ip], szIP, g_Cvars[ip_bantime], szAuth);

	g_Data[0] = Check;
	g_Data[1] = id;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
}

public SQL_Handler(failstate, Handle:query, err[], errcode, dt[], datasize)
{
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED, TQUERY_QUERY_FAILED:
		{
			new szPrefix[32];
			switch(dt[0])
			{
				case Ban: 	szPrefix = "Player Ban";
				case Unban: 	szPrefix = "Player Unban";
				case Update:	szPrefix = "Player Update";
				case Check: 	szPrefix = "Check Ban";
				case Search:	szPrefix = "Search Bans";
				case Expired:	szPrefix = "Expired Items";
				case GetServer:	szPrefix = "Get Server Info";
				case AddServer:	szPrefix = "Add Server Info";
			}

			log_amx("[SQL ERROR #%d][%s] %s", errcode, szPrefix, err);
			return;
		}
	}
	new id = dt[1];
	switch(dt[0])
	{
		case Unban: UTIL_console_print(id, "[Player Unban] Player %s", SQL_AffectedRows(query) ? "was unbanned" : "not found");
		case Check:
		{
			if(SQL_NumResults(query))
			{
				new szAuth[MAX_AUTHID_LENGTH], szName[MAX_NAME_LENGTH * 2], szAdmin[MAX_NAME_LENGTH * 2], szReason[64];

				SQL_ReadResult(query, 0, szAuth, charsmax(szAuth));
				SQL_ReadResult(query, 1, szName, charsmax(szName));
				SQL_ReadResult(query, 2, szAdmin, charsmax(szAdmin));
				SQL_ReadResult(query, 3, szReason, charsmax(szReason));
				new b_time = SQL_ReadResult(query, 4);
				new b_len = SQL_ReadResult(query, 5);

				UserKick(id, szAuth, szName, szAdmin, szReason, b_time, b_len);

				formatex(szQuery, charsmax(szQuery),
					"UPDATE `%s_bans` SET `ban_kicks` = ban_kicks + 1 WHERE `server_ip` = '%s' AND `ban_created` = '%d' AND `ban_length` = '%d'",
						g_szTablePrefix,
						g_Cvars[srv_ip],
						b_time,
						b_len
					);
				g_Data[0] = Update;
				SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
			}
			else if(g_playerData[id][pstate] == ban)
				BanAction(0, id);
			else	g_playerData[id][pstate] = checked;
		}
		case Search:
		{
			if(!SQL_NumResults(query))
				UTIL_console_print(id, "[Search Ban] %L", id, "BAN_NOT_FOUND");
			else
			{
				new szAuth[MAX_AUTHID_LENGTH], szName[MAX_NAME_LENGTH * 2], szAdmin[MAX_NAME_LENGTH * 2], szReason[64], szBanExp[64], iBanLen;

				while(SQL_MoreResults(query))
				{
					SQL_ReadResult(query, 0, szName, charsmax(szName));
					SQL_ReadResult(query, 1, szAuth, charsmax(szAuth));
					SQL_ReadResult(query, 2, szAdmin, charsmax(szAdmin));
					SQL_ReadResult(query, 3, szReason, charsmax(szReason));
					iBanLen = SQL_ReadResult(query, 5);

					if(!iBanLen)
						formatex(szBanExp, charsmax(szBanExp), "%L", id, "NOT_EXPIRED");
					else
					{
						get_time_length(
							id,
							SQL_ReadResult(query, 4) + iBanLen * 60,
							timeunit_seconds,
							szBanExp,
							charsmax(szBanExp)
						);
					}
					UTIL_console_print(
						id,
						"Player %s<%s> - Admin %s - Reason %s - Ban expired %s",
							szName,
							szAuth,
							szAdmin,
							szReason,
							szBanExp
					);

					SQL_NextRow(query);
				}
			}
		}
		case GetServer:
		{
			if(!SQL_NumResults(query))
			{
				formatex(szQuery, charsmax(szQuery),
					"INSERT INTO `%s_serverinfo` (`timestamp`, `hostname`, `address`, `gametype`, `amxban_version`) \
						VALUES ('%d', '%s', '%s', 'cstrike', 'lite_bans')",
				g_szTablePrefix, get_systime(), g_Cvars[srv_name], g_Cvars[srv_ip]);

				g_Data[0] = AddServer;
				SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
			}
		}
		case Ban:
		{
			g_arrKickData[id][bid] = SQL_GetInsertId(query);

			new Float:fDelay = get_pcvar_float(g_pCvars[delay]);
			set_task((fDelay < 1.0) ? 1.0 : fDelay, "Task__Motd", id);
		}
		case UnbanMenu:
		{
			if(!SQL_NumResults(query))
				UTIL_console_print(id, "[Unban Menu] %L", id, "UNBANMENU_PLAYERS_NOT_FOUND");
			else
			{
				new str[190];
				formatex(str, charsmax(str), "%L", LANG_SERVER, "UNBANMENU_TITLE");
				new menu = menu_create(str, "UnBanMenuHandler");

				new idStr[5];
				new szName[MAX_NAME_LENGTH];
				new szAdmin[MAX_NAME_LENGTH];
				new szMenuItem[MAX_NAME_LENGTH * 2 + 10];

				if(get_user_flags(id) & g_Cvars[superadmin])
				{
					while(SQL_MoreResults(query))
					{
						num_to_str(SQL_ReadResult(query, 0), idStr, charsmax(idStr));
						SQL_ReadResult(query, 1, szName, charsmax(szName));
						SQL_ReadResult(query, 2, szAdmin, charsmax(szAdmin));

						formatex(szMenuItem, charsmax(szMenuItem), "%s \d[\y%s\d]", szName, szAdmin);
						menu_additem(menu, szMenuItem, idStr);

						SQL_NextRow(query);
					}
				}
				else
				{
					while(SQL_MoreResults(query))
					{
						num_to_str(SQL_ReadResult(query, 0), idStr, charsmax(idStr));
						SQL_ReadResult(query, 1, szName, charsmax(szName));

						formatex(szMenuItem, charsmax(szMenuItem), szName);
						menu_additem(menu, szMenuItem, idStr);

						SQL_NextRow(query);
					}
				}

				menu_display(id, menu, 0);
			}
		}
		case OffbanMenu, Expired, Update, AddServer: {}
	}
}

MenusHandler(id, menu, item, mmenu)
{
	if(item != MENU_EXIT)
	{
		new _access, rsn[64], pid[10], CallBack;
		menu_item_getinfo(menu, item, _access, pid, charsmax(pid), rsn, charsmax(rsn), CallBack);

		switch(mmenu)
		{
			case 1:
			{
				g_arrBanData[id][index] = pid[0];
				menu_display(id, g_Cvars[static_reasons] ? g_iReasonMenu : g_iTimeMenu, 0);
			}
			case 2:
			{
				new pre = g_arrBanData[id][bantime];
				g_arrBanData[id][bantime] = str_to_num(pid);
				if(pre == -1 || !g_Cvars[static_reasons])
					client_cmd(id, "messagemode banreason");
				else
				{
					if(g_arrBanData[id][index] > 32)
						OffBanAction(id, g_arrBanData[id][index] - 33);
					else 	BanAction(id, g_arrBanData[id][index]);
				}
			}
			case 3:
			{
				g_arrBanData[id][bantime] = str_to_num(pid);
				if(g_arrBanData[id][bantime] == -1)
					menu_display(id, g_iTimeMenu, 0);
				else
				{
					copy(g_arrBanData[id][reason], charsmax(g_arrBanData[][reason]), rsn);

					if(g_Cvars[static_time])
					{
						if(g_arrBanData[id][index] > 32)
							OffBanAction(id, g_arrBanData[id][index] - 33);
						else 	BanAction(id, g_arrBanData[id][index]);
					}
					else 	menu_display(id, g_iTimeMenu, 0);
				}
			}
			case 4:
			{
				formatex(szQuery, charsmax(szQuery), "DELETE FROM `%s_bans` WHERE `bid` = '%d'", g_szTablePrefix, str_to_num(pid));

				g_Data[0] = Unban;
				g_Data[1] = id;
				SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
			}
			case 5:
			{
				g_arrBanData[id][index] = pid[0] + 33;
				menu_display(id, g_Cvars[static_reasons] ? g_iReasonMenu : g_iTimeMenu, 0);
			}
		}
	}
	if(mmenu == 1)
		menu_destroy(menu);
	return PLUGIN_HANDLED;
}

BanAction(admin, banned)
{
	if(!is_user_connected(banned))
		return UTIL_console_print(admin, "^n^n%L^n^n", admin, "USER_NOT_CONN_CNSL");

	if(admin)
	{
		if(~get_user_flags(admin) & g_Cvars[superadmin])
		{
			if(get_user_flags(banned) & ADMIN_IMMUNITY)
				return UTIL_console_print(admin, "^n^n%L^n^n", admin, "USER_IMMUNITY_CNSL");
		}
	}

	new szIp[16], szAuth[MAX_AUTHID_LENGTH], szaIP[16], szaAuth[MAX_AUTHID_LENGTH];
	new szaName[64], szuName[64];
	get_user_ip(banned, szIp, charsmax(szIp), 1);

	get_user_authid(banned, szAuth, charsmax(szAuth));
	get_user_name(banned, szuName, charsmax(szuName));
	new iSysTime = get_systime();

	if(admin)
	{
		get_user_ip(admin, szaIP, charsmax(szaAuth), 1);
		get_user_authid(admin, szaAuth, charsmax(szaAuth));
		get_user_name(admin, szaName, charsmax(szaName));
	}
	else
	{
		formatex(szaIP, charsmax(szaIP), g_Cvars[srv_ip]);
		formatex(szaAuth, charsmax(szaAuth), "SERVER_ID");
		copy(szaName, charsmax(szaName), g_Cvars[srv_name]);
	}

	if(g_Cvars[hud_msg][0])
	{
		new szBanLen[64];
		if(!g_arrBanData[admin][bantime])
			formatex(szBanLen, charsmax(szBanLen), "%L", LANG_SERVER, "BAN_PERMANENT");
		else	get_time_length(banned, g_arrBanData[admin][bantime], timeunit_minutes, szBanLen, charsmax(szBanLen));

		static HudSyncObj;
		if(HudSyncObj || (HudSyncObj = CreateHudSyncObj()))
		{
			set_hudmessage(
				.red = g_Cvars[hud_msg_color][0],
				.green = g_Cvars[hud_msg_color][1],
				.blue = g_Cvars[hud_msg_color][2],
				.x = g_fHudPos[0],
				.y = g_fHudPos[1],
				.holdtime = 10.0,
				.channel = 4
			);
			ClearSyncHud(0, HudSyncObj);

			new szText[512]; copy(szText, charsmax(szText), g_Cvars[hud_msg]);
			replace_string(szText, charsmax(szText), "%n%", "^n");
			replace_string(szText, charsmax(szText), "%player%", szuName);
			replace_string(szText, charsmax(szText), "%admin%", szaName);
			replace_string(szText, charsmax(szText), "%banlen%", szBanLen);
			replace_string(szText, charsmax(szText), "%reason%", g_arrBanData[admin][reason]);
			ShowSyncHudMsg(0, HudSyncObj, szText);
		}
	}
/* Вызываем форвард Pre Banned */
	new ret; ExecuteForward(g_fwdHandle[PreBan], ret, banned, admin, g_arrBanData[admin][bantime]);
/* Экранируем */
	mysql_escape_string(szuName, charsmax(szuName));
	mysql_escape_string(g_arrBanData[admin][reason], charsmax(g_arrBanData[][reason]));
	mysql_escape_string(szaName, charsmax(szaName));

	g_bBanned[banned] = true;

	if(g_Cvars[cookie_link][0])
	{
	/* Генерим куку */
		new szTempMd5[64], md5Buff[34];
		formatex(szTempMd5, charsmax(szTempMd5), "%s %d", szAuth, iSysTime);
		hash_string(szTempMd5, Hash_Md5, md5Buff, charsmax(md5Buff));

		formatex(
			szQuery,
			charsmax(szQuery),
			"INSERT INTO `%s_bans` \
			( \
				`player_ip`, \
				`player_id`, \
				`player_nick`, \
				`admin_ip`, \
				`admin_id`, \
				`admin_nick`, \
				`ban_reason`, \
				`ban_created`, \
				`ban_length`, \
				`server_ip`, \
				`server_name`, \
				`cookie`, \
				`expired` \
			) \
			VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s', '%s', '0')",
				g_szTablePrefix,
				szIp,
				szAuth,
				szuName,
				szaIP,
				szaAuth,
				szaName,
				g_arrBanData[admin][reason],
				iSysTime,
				g_arrBanData[admin][bantime],
				g_Cvars[srv_ip],
				g_Cvars[srv_name],
				md5Buff
		);
	}
	else
	{
		formatex(
			szQuery,
			charsmax(szQuery),
			"INSERT INTO `%s_bans` \
			( \
				`player_ip`, \
				`player_id`, \
				`player_nick`, \
				`admin_ip`, \
				`admin_id`, \
				`admin_nick`, \
				`ban_reason`, \
				`ban_created`, \
				`ban_length`, \
				`server_ip`, \
				`server_name`, \
				`expired` \
			) \
			VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s', '0')",
				g_szTablePrefix,
				szIp,
				szAuth,
				szuName,
				szaIP,
				szaAuth,
				szaName,
				g_arrBanData[admin][reason],
				iSysTime,
				g_arrBanData[admin][bantime],
				g_Cvars[srv_ip],
				g_Cvars[srv_name]
		);
	}

	g_Data[0] = Ban;
	g_Data[1] = banned;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));

	copy(g_arrKickData[banned][auth], charsmax(g_arrKickData[][auth]), szAuth);
	copy(g_arrKickData[banned][u_name], charsmax(g_arrKickData[][u_name]), szuName);
	copy(g_arrKickData[banned][a_name], charsmax(g_arrKickData[][a_name]), szaName);
	copy(g_arrKickData[banned][ban_reason], charsmax(g_arrKickData[][ban_reason]), g_arrBanData[admin][reason]);
	g_arrKickData[banned][ban_time] = iSysTime;
	g_arrKickData[banned][ban_length] = g_arrBanData[admin][bantime];

	return PLUGIN_HANDLED;
}

OffBanAction(admin, player)
{
	new szaName[64], szaIP[16], szaAuth[MAX_AUTHID_LENGTH];
	get_user_ip(admin, szaIP, charsmax(szaAuth), 1);
	get_user_authid(admin, szaAuth, charsmax(szaAuth));
	get_user_name(admin, szaName, charsmax(szaName));

	mysql_escape_string(g_arrBanData[admin][reason], charsmax(g_arrBanData[][reason]));
	mysql_escape_string(szaName, charsmax(szaName));

	new iSysTime = get_systime();
	ArrayGetArray(g_aOffPlayers, player, g_arrOffPlayers);

	if(g_Cvars[cookie_link][0])
	{
	/* Генерим куку */
		new szTempMd5[64], md5Buff[34];
		formatex(szTempMd5, charsmax(szTempMd5), "%s %d", g_arrOffPlayers[authid], iSysTime);
		hash_string(szTempMd5, Hash_Md5, md5Buff, charsmax(md5Buff));

		formatex(
			szQuery,
			charsmax(szQuery),
			"INSERT INTO `%s_bans` \
			( \
				`player_ip`, \
				`player_id`, \
				`player_nick`, \
				`admin_ip`, \
				`admin_id`, \
				`admin_nick`, \
				`ban_reason`, \
				`ban_created`, \
				`ban_length`, \
				`server_ip`, \
				`server_name`, \
				`cookie`, \
				`expired` \
			) \
			VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s', '%s', '0')",
				g_szTablePrefix,
				g_arrOffPlayers[ip],
				g_arrOffPlayers[authid],
				g_arrOffPlayers[name],
				szaIP,
				szaAuth,
				szaName,
				g_arrBanData[admin][reason],
				iSysTime,
				g_arrBanData[admin][bantime],
				g_Cvars[srv_ip],
				g_Cvars[srv_name],
				md5Buff
		);
	}
	else
	{
		formatex(
			szQuery,
			charsmax(szQuery),
			"INSERT INTO `%s_bans` \
			( \
				`player_ip`, \
				`player_id`, \
				`player_nick`, \
				`admin_ip`, \
				`admin_id`, \
				`admin_nick`, \
				`ban_reason`, \
				`ban_created`, \
				`ban_length`, \
				`server_ip`, \
				`server_name`, \
				`expired` \
			) \
			VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s', '0')",
				g_szTablePrefix,
				g_arrOffPlayers[ip],
				g_arrOffPlayers[authid],
				g_arrOffPlayers[name],
				szaIP,
				szaAuth,
				szaName,
				g_arrBanData[admin][reason],
				iSysTime,
				g_arrBanData[admin][bantime],
				g_Cvars[srv_ip],
				g_Cvars[srv_name]
		);
	}

	g_Data[0] = OffbanMenu;
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", szQuery, g_Data, sizeof(g_Data));
	ArrayDeleteItem(g_aOffPlayers, player);
}

public Task__Kick(id)
{
	if(is_user_connected(id))
	{
		UserKick(
			id,
			g_arrKickData[id][auth],
			g_arrKickData[id][u_name],
			g_arrKickData[id][a_name],
			g_arrKickData[id][ban_reason],
			g_arrKickData[id][ban_time],
			g_arrKickData[id][ban_length]
		);

		arrayset(g_arrKickData[id], 0, KickData);
	}
}

public Task__Motd(id)
{
	if(is_user_connected(id))
	{
		if(g_Cvars[cookie_link][0])
		{
			new szBuffer[190];
			formatex(szBuffer, charsmax(szBuffer), "%s?ban=1&bid=%d", g_Cvars[cookie_link], g_arrKickData[id][bid]);
			show_motd(id, szBuffer, "You are banned!");
		}
		set_task(1.5, "Task__Kick", id);
	}
}

UserKick(id, b_auth[], b_user[], b_admin[], b_reason[], b_time, b_length)
{
	static szBanDate[24], szExpired[24], szBanLen[64];
	format_time(szBanDate, charsmax(szBanDate), "%d.%m.%Y - %H:%M:%S", b_time);

	switch(b_length)
	{
		case 0:
		{
			formatex(szExpired, charsmax(szExpired), "%L", id, "NOT_EXPIRED");
			formatex(szBanLen, charsmax(szBanLen), "%L", id, "BAN_LEN_PERM");
		}
		default:
		{
			format_time(szExpired, charsmax(szExpired), "%d.%m.%Y - %H:%M:%S", b_time + b_length * 60);
			get_time_length(id, b_length, timeunit_minutes, szBanLen, charsmax(szBanLen));
		}
	}

	UTIL_console_print(id, "^n");
	for(new i, szText[256]; i < g_iStrings; i++)
	{
		copy(szText, charsmax(szText), g_szConsole[i]);
		replace_string(szText, charsmax(szText), "%player%", b_user);
		replace_string(szText, charsmax(szText), "%admin%", b_admin);
		replace_string(szText, charsmax(szText), "%steamid%", b_auth);
		replace_string(szText, charsmax(szText), "%reason%", b_reason);
		replace_string(szText, charsmax(szText), "%bandate%", szBanDate);
		replace_string(szText, charsmax(szText), "%banlen%", szBanLen);
		replace_string(szText, charsmax(szText), "%banexpired%",szExpired);
		UTIL_console_print(id, szText);
	}
	UTIL_console_print(id, "^n");

	set_task(0.5, "KickPlayer", id);
}

public KickPlayer(id)
{
	if(is_user_connected(id))
		server_cmd("kick #%d %L", get_user_userid(id), id, "BAN_KICK_MSG");
}

CmdAccess(id, flags)
	return (get_user_flags(id) & flags);

LoadCvars()
{
	get_localinfo("amxx_configsdir", g_szConfigDir, charsmax(g_szConfigDir));
	add(g_szConfigDir, charsmax(g_szConfigDir), "/LB");

	new szConfig[64];
	formatex(szConfig, charsmax(szConfig), "%s/main.cfg", g_szConfigDir);
	server_cmd("exec %s", szConfig);
	server_exec();

	new flags[3];
	get_pcvar_string(g_pCvars[sadmin], flags, charsmax(flags));
	g_Cvars[superadmin] = read_flags(flags);

	get_pcvar_string(g_pCvars[srvname], g_Cvars[srv_name], charsmax(g_Cvars[srv_name])); mysql_escape_string(g_Cvars[srv_name], charsmax(g_Cvars[srv_name]));
	get_pcvar_string(g_pCvars[srvip], g_Cvars[srv_ip], charsmax(g_Cvars[srv_ip]));
	get_pcvar_string(g_pCvars[lnkck], g_Cvars[cookie_link], charsmax(g_Cvars[cookie_link]));
	g_Cvars[global_bans] = get_pcvar_num(g_pCvars[allbans]);
	g_Cvars[ip_bantime] = get_pcvar_num(g_pCvars[ipban]) * 60;
	g_Cvars[static_reasons] = get_pcvar_num(g_pCvars[reasons]);
	g_Cvars[static_time]= get_pcvar_num(g_pCvars[rsnbtm]);

	get_pcvar_string(g_pCvars[hud], g_Cvars[hud_msg], charsmax(g_Cvars[hud_msg]));
	if(g_Cvars[hud_msg][0])
	{
		new string[15];get_pcvar_string(g_pCvars[hudpos], string, charsmax(string));
		new str[3][5]; parse(string, str[0], charsmax(str[]), str[1], charsmax(str[]));
		g_fHudPos[0] = str_to_float(str[0]);
		g_fHudPos[1] = str_to_float(str[1]);

		get_pcvar_string(g_pCvars[hudclr], string, charsmax(string));
		parse(string, str[0], charsmax(str[]), str[1], charsmax(str[]), str[2], charsmax(str[]));
		g_Cvars[hud_msg_color][0] = str_to_num(str[0]);
		g_Cvars[hud_msg_color][1] = str_to_num(str[1]);
		g_Cvars[hud_msg_color][2] = str_to_num(str[2]);
	}
/* SQL cvars and cache connect */
	new szHost[64], szUser[64], szPass[64], szDB[64];
	get_pcvar_string(g_pCvars[host], szHost, charsmax(szHost));
	get_pcvar_string(g_pCvars[user], szUser, charsmax(szUser));
	get_pcvar_string(g_pCvars[pass], szPass, charsmax(szPass));
	get_pcvar_string(g_pCvars[db],   szDB,   charsmax(szDB));
	get_pcvar_string(g_pCvars[pref], g_szTablePrefix, charsmax(g_szTablePrefix));

	SQL_SetAffinity("mysql");
	g_hSqlTuple = SQL_MakeDbTuple(szHost, szUser, szPass, szDB, 1);

	new errcode,
		errstr[128],
		Handle:hTest = SQL_Connect(g_hSqlTuple, errcode, errstr, charsmax(errstr));

	if(hTest == Empty_Handle)
	{
		new szError[128];
		formatex(szError, charsmax(szError), "[SQL ERROR #%d] %s", errcode, errstr);
		set_fail_state(szError);
	}
	else
	{
		SQL_FreeHandle(hTest);
		SQL_SetCharset(g_hSqlTuple, "utf8");

		new ret; ExecuteForward(g_fwdHandle[SqlInit], ret, g_hSqlTuple);
	}
}

LoadConfigs()
{
	new szConfig[64], szBuffer[190], fp;
	if(g_Cvars[static_reasons])
	{
		formatex(szConfig, charsmax(szConfig), "%s/reasons.ini", g_szConfigDir);
		fp = fopen(szConfig, "rt");
		if(!fp)
		{
			new szError[96]; formatex(szError, charsmax(szError), "File '%s' not found or not read!", szConfig);
			set_fail_state(szError);
		}

		new array[2][64];
		if(g_Cvars[static_time])
		{
			while(!feof(fp))
			{
				fgets(fp, szBuffer, charsmax(szBuffer)); trim(szBuffer);
				if(!szBuffer[0] || szBuffer[0] == ';')
					continue;
				if(parse(szBuffer, array[0], charsmax(array[]), array[1], charsmax(array[])) == 2)
					menu_additem(g_iReasonMenu, array[0], array[1]);
			}
		}
		else
		{
			new i, z[3];
			while(!feof(fp))
			{
				fgets(fp, szBuffer, charsmax(szBuffer)); trim(szBuffer);
				if(!szBuffer[0] || szBuffer[0] == ';')
					continue;

				z[0] = i; menu_additem(g_iReasonMenu, szBuffer, z);
				i++;
			}
		}
		fclose(fp);
		if(get_pcvar_num(g_pCvars[crsn]))
		{
			menu_addblank(g_iReasonMenu, 0);
			new str[64]; formatex(str, charsmax(str), "%L", LANG_SERVER, "CUSTOM_REASON");
			menu_additem(g_iReasonMenu, str, "-1");
		}
	}

	formatex(szConfig, charsmax(szConfig), "%s/times.ini", g_szConfigDir);
	fp = fopen(szConfig, "rt");
	if(!fp)
	{
		new szError[96]; formatex(szError, charsmax(szError), "File '%s' not found or not read!", szConfig);
		set_fail_state(szError);
	}

	new array[3][64];
	while(!feof(fp))
	{
		fgets(fp, szBuffer, charsmax(szBuffer)); trim(szBuffer);
		if(!szBuffer[0] || szBuffer[0] == ';')
				continue;
		if(parse(szBuffer, array[0], charsmax(array[]), array[1], charsmax(array[])) == 2)
			menu_additem(g_iTimeMenu, array[0], array[1]);
	}
	fclose(fp);

	formatex(szConfig, charsmax(szConfig), "%s/console.ini", g_szConfigDir);
	fp = fopen(szConfig, "rt");
	if(!fp)
	{
		new szError[96]; formatex(szError, charsmax(szError), "File '%s' not found or not read!", szConfig);
		set_fail_state(szError);
	}

	while(!feof(fp) && g_iStrings < MAX_STRINGS)
	{
		fgets(fp, szBuffer, charsmax(szBuffer)); trim(szBuffer);
		if(szBuffer[0] && szBuffer[0] != ';')
			copy(g_szConsole[g_iStrings++], charsmax(g_szConsole[]), szBuffer);
	}
	fclose(fp);
}

stock cmd_target(id, const arg[])
{
	new player = find_player("bl", arg);
	if(player)
	{
		if(player != find_player("blj", arg))
		{
			UTIL_console_print(id, "%L", id, "MORE_CL_MATCHT");
			return PLUGIN_CONTINUE;
		}
	}
	else if((player = find_player("c", arg)) == 0 && arg[0] == '#' && arg[1])
	{
		player = find_player("k", str_to_num(arg[1]));
	}
	if(!player)
	{
		UTIL_console_print(id, "%L", id, "CL_NOT_FOUND");
		return PLUGIN_CONTINUE;
	}
	return player;
}

stock UTIL_console_print(const id, const szFmt[], any:...)
{
	static szMessage[256], iLen;
	vformat(szMessage, charsmax(szMessage), szFmt, 3);

	iLen = strlen(szMessage);
	szMessage[iLen++] = '^n';
	szMessage[iLen] = 0;

	if(is_user_connected(id))
	{
		message_begin(MSG_ONE, SVC_PRINT, .player = id);
		write_string(szMessage);
		message_end();
	}
	else	server_print(szMessage);

	return PLUGIN_HANDLED;
}

stock mysql_escape_string(output[], len)
{
	static const szReplaceIn[][] = { "\\", "\0", "\n", "\r", "\x1a", "'", "^"" };
	static const szReplaceOut[][] = { "\\\\", "\\0", "\\n", "\\r", "\Z", "\'", "\^"" };
	for(new i; i < sizeof szReplaceIn; i++)
		replace_string(output, len, szReplaceIn[i], szReplaceOut[i]);
}