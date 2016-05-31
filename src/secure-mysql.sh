#! /bin/sh
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
# Edited for a use case scenario by Haruka Ikazan <haruka.ikazan@gmail.com>
#
# A non-interactive replacement for mysql_secure_installation
#
# HI: We desire to proceed even if the root user has a password.
#     In this case the provided password should be the root password.
#     Therefore...  If no root password: establish it and secure MySQL.
#                   If there is a password: use it to secure MySQL.
#
# Tested on CentOS 6, CentOS 7, Ubuntu 12.04 LTS (Precise Pangolin), Ubuntu
# 14.04 LTS (Trusty Tahr).

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

#{{{ Functions

usage() {
cat << _EOF_

Usage: ${0} "ROOT PASSWORD"

  with "ROOT PASSWORD" the desired password for the database root user.

Use quotes if your password contains spaces or other special characters.
_EOF_
}

# Predicate that returns exit status 0 if the database root password
# is set, a nonzero exit status otherwise.
is_mysql_root_password_set() {
  ! mysqladmin --user=root status > /dev/null 2>&1
}

# Predicate that returns exit status 0 if the mysql(1) command is available,
# nonzero exit status otherwise.
is_mysql_command_available() {
  which mysql > /dev/null 2>&1
}

#}}}
#{{{ Command line parsing

if [ "$#" -ne "1" ]; then
  echo "Expected 1 argument, got $#" >&2
  usage
  exit 2
fi

#}}}
#{{{ Variables
db_root_password="${1}"
lockdown="mysql --user=root"
setpassword="UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';"
#}}}

# Script proper

if ! is_mysql_command_available; then
  echo "The MySQL/MariaDB client mysql(1) is not installed."
  exit 1
fi

if is_mysql_root_password_set; then
  # HI: Log in with the provided password and trash the setpassword command.
  echo "Database root password already set"
  lockdown="mysql --user=root -p$db_root_password"
  setpassword=
fi

$lockdown <<_EOF_
  $setpassword
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_
