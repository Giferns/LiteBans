<?php
error_reporting(0);
include 'config.php';

if($cookiename) { 
	$db = new mysqli($mysql_host, $mysql_user, $mysql_pass, $mysql_dbdb);
	if($db->connect_error) {
		exit('ERROR[#'.$db->connect_errno.'] '.$db->connect_error.'');
	} else {
		if($db->multi_query(GetTables() . " ALTER TABLE `{$prefix_tables}_bans` ADD `cookie` text COLLATE 'utf8_general_ci' NULL AFTER `server_name`;")) {
			echo 'Запрос успешно выполнен! Скрипт настроен правильно ^^<br>';
			RemoveInstaller();
		} else {
			if(strpos($db->error, "Duplicate column name 'cookie'") !== false) {
				echo 'Установка завершена!<br>';
				RemoveInstaller();
			}
			else	exit($db->error);
		}
	}
	$db->close();
} else {
	echo 'Жизнь - боль<br>Вы не заполнили переменную $cookiename<br>Исправьте ошибку и запустите установщик заново!';
}

function RemoveInstaller() {
	global $auto_remove_install;
	
	if($auto_remove_install == true) {
		if(unlink('install.php')) {
			echo 'Установщик успешно удален!';
		} else {
			echo 'Возникли проблемы с удалением файла install.php! Удалите самостоятельно!';
		}
	} else {
		echo 'Удалите файл install.php';
	}
}

function GetTables() {
	global $prefix_tables;
	
	return "CREATE TABLE IF NOT EXISTS `{$prefix_tables}_admins_servers` (
		admin_id int(11) NULL,
		server_id int(11) NULL,
		custom_flags varchar(32) NOT NULL,
		use_static_bantime enum('yes','no') NOT NULL DEFAULT 'yes'
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_amxadmins` (
		id int(12) NULL auto_increment,
		username varchar(32) NULL,
		password varchar(50) NULL,
		access varchar(32) NULL,
		flags varchar(32) NULL,
		steamid varchar(32) NULL,
		nickname varchar(32) NULL,
		icq int(9) NULL,
		ashow int(11) NULL,
		created int(11) NULL,
		expired int(11) NULL,
		days int(11) NULL,
		PRIMARY KEY (id),
		KEY steamid (steamid)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_bans` (
		bid int(11) NULL auto_increment,
		player_ip varchar(32) NULL,
		player_id varchar(35) NULL,
		player_nick varchar(100) NULL DEFAULT 'Unknown',
		admin_ip varchar(32) NULL,
		admin_id varchar(35) DEFAULT 'Unknown',
		admin_nick varchar(100) NULL DEFAULT 'Unknown',
		ban_type varchar(10) NULL DEFAULT 'S',
		ban_reason varchar(100) NULL,
		cs_ban_reason varchar(100) NULL,
		ban_created int(11) NULL,
		ban_length int(11) NULL,
		server_ip varchar(32) NULL,
		server_name varchar(100) NULL DEFAULT 'Unknown',
		ban_kicks int(11) NOT NULL DEFAULT '0',
		expired int(1) NOT NULL DEFAULT '0',
		imported int(1) NOT NULL DEFAULT '0',
		PRIMARY KEY (bid),
		KEY player_id (player_id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_bans_edit` (
		`id` int(11) NOT NULL auto_increment,
		`bid` int(11) NOT NULL,
		`edit_time` int(11) NOT NULL,
		`admin_nick` varchar(32) NOT NULL DEFAULT 'unknown',
		`edit_reason` varchar(255) NOT NULL,
		PRIMARY KEY (`id`)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_bbcode` (
		id int(11) NULL auto_increment,
		open_tag varchar(32) NULL,
		close_tag varchar(32) NULL,
		url varchar(32) NULL,
		name varchar(32) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_comments` (
		id int(11) NULL auto_increment,
		name varchar(35) NULL,
		comment text NULL,
		email varchar(100) NULL,
		addr varchar(32) NULL,
		date int(11) NULL,
		bid int(11) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_files` (
		id int(11) NULL auto_increment,
		upload_time int(11) NULL,
		down_count int(11) NULL,
		bid int(11) NULL,
		demo_file varchar(100) NULL,
		demo_real varchar(100) NULL,
		file_size int(11) NULL,
		comment text NULL,
		name varchar(64) NULL,
		email varchar(64) NULL,
		addr varchar(32) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_levels` (
		level int(12) NULL,
		bans_add enum('yes','no') NULL DEFAULT 'no',
		bans_edit enum('yes','no','own') NULL DEFAULT 'no',
		bans_delete enum('yes','no','own') NULL DEFAULT 'no',
		bans_unban enum('yes','no','own') NULL DEFAULT 'no',
		bans_import enum('yes','no') NULL DEFAULT 'no',
		bans_export enum('yes','no') NULL DEFAULT 'no',
		amxadmins_view enum('yes','no') NULL DEFAULT 'no',
		amxadmins_edit enum('yes','no') NULL DEFAULT 'no',
		webadmins_view enum('yes','no') NULL DEFAULT 'no',
		webadmins_edit enum('yes','no') NULL DEFAULT 'no',
		websettings_view enum('yes','no') NULL DEFAULT 'no',
		websettings_edit enum('yes','no') NULL DEFAULT 'no',
		permissions_edit enum('yes','no') NULL DEFAULT 'no',
		prune_db enum('yes','no') NULL DEFAULT 'no',
		servers_edit enum('yes','no') NULL DEFAULT 'no',
		ip_view enum('yes','no') NULL DEFAULT 'no',
		PRIMARY KEY (level)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_logs` (
		id int(11) NULL auto_increment,
		timestamp int(11) NULL,
		ip varchar(32) NULL,
		username varchar(32) NULL,
		action varchar(64) NULL,
		remarks varchar(256) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_modulconfig` (
		id int(11) NULL auto_increment,
		menuname varchar(32) NULL,
		name varchar(32) NULL,
		`index` varchar(32) NULL,
		activ int(1) NOT NULL DEFAULT '1',
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_reasons` (
		id int(11) NULL auto_increment,
		reason varchar(100) NULL,
		static_bantime int(11) NOT NULL DEFAULT '0',
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_reasons_set` (
		id int(11) NULL auto_increment,
		setname varchar(32) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_reasons_to_set` (
		id int(11) NULL auto_increment,
		setid int(11) NOT NULL,
		reasonid int(11) NOT NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_serverinfo` (
		id int(11) NULL auto_increment,
		timestamp int(11) NULL,
		hostname varchar(100) NULL DEFAULT 'Unknown',
		address varchar(100) NULL,
		gametype varchar(32) NULL,
		rcon varchar(32) NULL,
		amxban_version varchar(32) NULL,
		amxban_motd varchar(250) NULL,
		motd_delay int(10) NULL DEFAULT '10',
		amxban_menu int(10) NOT NULL DEFAULT '1',
		reasons int(10) NULL,
		timezone_fixx int(11) NOT NULL DEFAULT '0',
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_smilies` (
		id int(5) NULL auto_increment,
		code varchar(32) NULL,
		url varchar(32) NULL,
		name varchar(32) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_usermenu` (
		id int(11) NULL auto_increment,
		pos int(11) NULL,
		activ tinyint(1) NOT NULL DEFAULT '1',
		lang_key varchar(64) NULL,
		url varchar(64) NULL,
		lang_key2 varchar(64) NULL,
		url2 varchar(64) NULL,
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_webadmins` (
		id int(12) NULL auto_increment,
		username varchar(32) NULL,
		password varchar(32) NULL,
		level int(11) NULL DEFAULT '99',
		logcode varchar(64) NULL,
		email varchar(64) NULL,
		last_action int(11) NULL,
		try int(1) NOT NULL default '0',
		PRIMARY KEY (id),UNIQUE (username,email)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_webconfig` (
		id int(11) NULL auto_increment,
		cookie varchar(32) NULL,
		bans_per_page int(11) NULL,
		design varchar(32) NULL,
		banner varchar(64) NULL,
		banner_url varchar(128) NOT NULL,
		default_lang varchar(32) NULL,
		start_page varchar(64) NULL,
		show_comment_count int(1) NULL DEFAULT '1',
		show_demo_count int(1) NULL DEFAULT '1',
		show_kick_count int(1) NULL DEFAULT '1',
		demo_all int(1) NOT NULL DEFAULT '0',
		comment_all int(1) NOT NULL DEFAULT '0',
		use_capture int(1) NULL DEFAULT '1',
		max_file_size int(11) NULL DEFAULT '2',
		file_type varchar(64) NULL DEFAULT 'dem,zip,rar,jpg,gif',
		auto_prune int(1) NOT NULL DEFAULT '0',
		`max_offences` SMALLINT NOT NULL DEFAULT '10',
		`max_offences_reason` VARCHAR( 128 ) NOT NULL DEFAULT 'max offences reached',
		use_demo int(1) NULL DEFAULT '1',
		use_comment int(1) NULL DEFAULT '1',
		PRIMARY KEY (id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	CREATE TABLE IF NOT EXISTS `{$prefix_tables}_flagged` (
		`fid` int(11) NOT NULL auto_increment,
		`player_ip` varchar(32) default NULL,
		`player_id` varchar(35) default NULL,
		`player_nick` varchar(100) default 'Unknown',
		`admin_ip` varchar(32) default NULL,
		`admin_id` varchar(35) default NULL,
		`admin_nick` varchar(100) default 'Unknown',
		`reason` varchar(100) default NULL,
		`created` int(11) default NULL,
		`length` int(11) default NULL,
		`server_ip` varchar(100) default NULL,
		PRIMARY KEY  (`fid`),
		KEY `player_id` (`player_id`)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;";
}