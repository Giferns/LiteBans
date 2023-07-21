#include <amxmodx>

#define SCREENS_NUM	5			// Количество скринов
#define LINK_TO_UNBAN 	"vk.com/neugomonserv"	// Ссылка, куда скидывать

forward user_banned_pre(id);
forward fbans_player_banned_pre(id, userid);

public plugin_init()
{
	register_plugin("ScreenMaker", "1.1", "neygomon");
	register_clcmd("amx_screenmenu", "CmdScreenMenu", ADMIN_BAN);
}

public plugin_cfg()
{
	server_cmd("amx_addmenuitem ^"Сделать скрины^" ^"amx_screenmenu^" ^"d^" ^"ScreenMaker^"");
	server_exec();
	
	set_task(1.0, "SetKickDelay");
}

public SetKickDelay()
{
	server_cmd("lb_kick_delay %d", SCREENS_NUM + 1);
	server_cmd("fb_kick_delay %d", SCREENS_NUM + 1);
}

public user_banned_pre(id)
	ScreenAction(id, 0, 1);

public fbans_player_banned_pre(id, userid)
	if(is_user_connected(id) && get_user_userid(id) == userid) 
		ScreenAction(id, 0, 1);

public CmdScreenMenu(id, level)
{
	if(~get_user_flags(id) & level)
	{
		client_print(id, print_notify, "* Недостаточно прав для использования этой команды!");
		return PLUGIN_HANDLED;
	}
	
	new menu = menu_create("\d[\rScreenMenu\d] \yВыберите игрока", "players_menu");
	new call = menu_makecallback("players_callback");
	
	menu_setprop(menu, MPROP_EXITNAME, "Выход");
	menu_setprop(menu, MPROP_BACKNAME, "Назад");
	menu_setprop(menu, MPROP_NEXTNAME, "Далее");
	
	new pl[32], pnum;
	get_players(pl, pnum, "ch");
	
	for(new i, pid[2], name[32]; i < pnum; i++)
	{
		pid[0] = pl[i];
		get_user_name(pl[i], name, charsmax(name));
		menu_additem(menu, name, pid, 0, call);
	}
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public players_callback(id, menu, item)
{
	new pid[2], _access, callback;
	new szItem[32], szNewItem[64];
	menu_item_getinfo(menu, item, _access, pid, charsmax(pid), szItem, charsmax(szItem), callback);
	
	if(pid[0] == id)
	{
		formatex(szNewItem, charsmax(szNewItem), "%s \d[\yВы\d]", szItem);
		menu_item_setname(menu, item, szNewItem);
		return ITEM_DISABLED;
	}
	else
	{
		new flags = get_user_flags(pid[0]);
		static lastId, flagsId; if(id != lastId) flagsId = get_user_flags(id);
		
		if(flags & ADMIN_IMMUNITY)
		{
			formatex(szNewItem, charsmax(szNewItem), "%s \d[\yИммунитет\d]", szItem);
			menu_item_setname(menu, item, szNewItem);
			return (flagsId & ADMIN_RCON) ? ITEM_ENABLED : ITEM_DISABLED;
		}
		else if(flags & ADMIN_MENU)
		{
			formatex(szNewItem, charsmax(szNewItem), "%s \d[\yАдмин\d]", szItem);
			menu_item_setname(menu, item, szNewItem);
			return (flagsId & ADMIN_RCON) ? ITEM_ENABLED : ITEM_DISABLED;
		}
	}
	return ITEM_ENABLED;
}

public players_menu(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	new pid[2], _access, call;
	menu_item_getinfo(menu, item, _access, pid, charsmax(pid), .callback = call);
	
	if(!is_user_connected(pid[0]))
		client_print(id, print_chat, "* Игрок покинул сервер");
	else
	{
		new name[32]; 	get_user_name(id, name, charsmax(name));
		new name2[32]; 	get_user_name(pid[0], name2, charsmax(name2));
		log_to_file("screen_maker.log", "Администратор %s сделал скрины игроку %s", name, name2);
		
		ScreenAction(pid[0], id, 0);
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public MakeScreen(id)
{
	if(is_user_connected(id))
		client_cmd(id, "snapshot");
	else	remove_task(id);	
}

ScreenAction(id, admin, ban)
{
	new szTime[22]; 
	get_time("%d.%m.%Y - %H:%M:%S", szTime, charsmax(szTime));
	
	new szAdmin[64];
	get_user_name(admin, szAdmin, charsmax(szAdmin));
	
	new szMap[32];
	get_mapname(szMap, charsmax(szMap));
	
	new szHUD[190];
	if(admin)
		formatex(szHUD, charsmax(szHUD), "Время %s^nАдминистратор %s^nКарта %s^nСкинуть в %s", szTime, szAdmin, szMap, LINK_TO_UNBAN);
	else	formatex(szHUD, charsmax(szHUD), "Время %s^nСервер %s^nКарта %s^nСкинуть в %s", szTime, szAdmin, szMap, LINK_TO_UNBAN);
	
	set_hudmessage(0, 200, 0, -1.0, 0.80, 0, 0.0, float(SCREENS_NUM + 1), 0.0, 0.1, -1);
	show_hudmessage(id, szHUD);
		
	if(ban) client_cmd(id, "stop");
	set_task(1.0, "MakeScreen", id, .flags = "a", .repeat = SCREENS_NUM);
}