<?php
$cookiename = '';	// набор букв/цифр. если не заполнить, то отвалится куки бан
$mysql_host = '';	// хост
$mysql_user = '';	// юзер
$mysql_pass = '';	// пароль
$mysql_dbdb = '';	// имя базы

$prefix_tables = 'amx';	// префикс таблиц в БД, по умолчанию, обычно, amx

$auto_remove_install = true;	// автоматически удалить скрипт install.php после установки. 
// поставьте false, если не хотите этого :D

$log_cookie_check = true;	// записывать в файл check_cookie.log успешно пойманных куками игроков 
// false отключает логирование