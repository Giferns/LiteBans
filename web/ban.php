<?php

require_once("config.php");

if(!$cookiename)
	exit('Error settings. Check config.php');
else
{
	$db = new mysqli($mysql_host, $mysql_user, $mysql_pass, $mysql_dbdb);
	if($db->connect_error) {
		exit('ERROR[#'.$db->connect_errno.'] '.$db->connect_error.'');
	} else {
		$db->set_charset('utf8');
	}
}

if(isset($_GET['reload']))
{
	$value = "http://".$_SERVER['HTTP_HOST']."/";
	$value .= "pic.swf?qqa=".htmlspecialchars($_GET['qqa']);
	$value .= "&bid=".htmlspecialchars($_GET['bid']);
	$value .= "&auth=".htmlspecialchars($_GET['auth']);

	echo '<html> 
		<body> 
			<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" width="1" height="1" id="mymoviename">
				<param name="movie" value="'.$value.'" /> 
				<param name="quality" value="high" /> 
				<param name="bgcolor" value="#ffffff" /> 
				<embed src="'.$value.'" quality="high" bgcolor="#ffffff" width="1" height="1" name="mymoviename" align="" type="application/x-shockwave-flash" /></embed> 
			</object> 
		</body>
	</html>';
}
elseif(isset($_GET['ban']))
{
	$bid = filter_input(INPUT_GET, 'bid', FILTER_VALIDATE_INT);
	if($ban = $db->query("SELECT * FROM `{$prefix_tables}_bans` WHERE `bid` = '{$bid}'")) {
		$row = $ban->fetch_array(MYSQLI_ASSOC);
		if($row['cookie']) {
			$cookie = htmlspecialchars($row['cookie'], ENT_QUOTES);
			$period = intval($row['ban_length']);
			$period = ($period === 0) ? (time() + 31536000) : (time() + $row['ban_length'] * 60);

			setcookie($cookiename, $cookie, $period);
			
			$value = '<META HTTP-EQUIV="SET-COOKIE" CONTENT="'.$cookiename.'='.$cookie.';expires='.date("D, d M Y H:i:s", $period).' GMT;path=/;">';
			$value .= '<iframe src="http://'.$_SERVER['HTTP_HOST'].'/';
			$value .= 'ban.php?reload=1';
			$value .= '&qqa='.$cookie;
			$value .= "&bid=".htmlspecialchars($bid);
			$value .= "&auth=".htmlspecialchars($row['ban_steamid']);
			$value .= '" width="1" height="1" align="left" frameborder="0"></iframe>';

			echo $value;
		}
	}
}
elseif(isset($_GET['check']) && 
	isset($_COOKIE[$cookiename]) && 
		($steam = filter_input(INPUT_GET, 'steam', FILTER_SANITIZE_FULL_SPECIAL_CHARS)) &&
			($ban = $db->query("SELECT * FROM `{$prefix_tables}_bans` WHERE `cookie` = '{$_COOKIE[$cookiename]}'")))
{
	$row = $ban->fetch_array(MYSQLI_ASSOC);
	
	if($row['bid'])
	{
		if($log_cookie_check == true)
		{
			$logfile = 'clogs/'.date('d.m.Y').'.log';
			
			file_put_contents($logfile, '============ '.date('H:i:s').' ==========' . PHP_EOL, FILE_APPEND);
			file_put_contents($logfile, 'bid: '.$row['bid'].' # Cookie: '.$_COOKIE[$cookiename] . PHP_EOL, FILE_APPEND);
			
			if($row['player_id'] != $steam)
				file_put_contents($logfile, 'Old Steam: '.$row['player_id'].' # New Steam: '.$steam . PHP_EOL, FILE_APPEND);
			else	file_put_contents($logfile, 'Steam: '.$steam . PHP_EOL, FILE_APPEND);
		}	
		
		$value = "http://".$_SERVER['HTTP_HOST']."/";
		$value .= "pic.swf?qqa=".htmlspecialchars($_COOKIE[$cookiename]);
		$value .= "&bid=".htmlspecialchars($row['id']);
		$value .= "&auth=".htmlspecialchars($steam);
		
		echo '<object width="1" height="0 frameborder="0">
			<param name="url" value="pic.swf">
			<embed src="'.$value.'" width="1" height="0" frameborder="0">
			</embed>
		</object>';

		$value = '<iframe src="http://'.$_SERVER['HTTP_HOST'].'/';
		$value .= "ban.php?reload=1";
		$value .= "&qqa=".htmlspecialchars($_COOKIE[$cookiename]);
		$value .= "&bid=".htmlspecialchars($row['id']);
		$value .= "&auth=".htmlspecialchars($steam);
		$value .= '" width="1" height="0" align="left" frameborder="0"></iframe>';
		
		echo $value;
		
		$db->query("UPDATE `{$prefix_tables}_bans` SET `player_id` = '{$steam}' WHERE `cookie` = '{$_COOKIE[$cookiename]}'");
	}
}

$db->close();
include 'motd.html';