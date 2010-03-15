package CATS::Connect;

#$db_user = "cats";
#$db_passwd = "cats";
#$db_dsn = "dbi\:Oracle\:host=192.168.1.252;sid=global";

#$db_dsn="dbi:InterBase:db=/usr/local/apache/CATS/ib_data/cats.gdb;ib_dialect=3";
$db_dsn="DBI:InterBase:host=localhost;db=cats;ib_dialect=3";
#$db_dsn="dbi:InterBase:host=webtest;port=3050;db=cats.gdb;ib_dialect=3";
$db_user="sysdba";
#$db_password="Tq1f";
$db_password="masterkey";

#$db_dsn="dbi:InterBase:db=d:/dev/CATS/ib_data/cats.gdb;ib_dialect=3;host=localhost";
#$db_user="sysdba";
#$db_passwd="masterkey";

1;
