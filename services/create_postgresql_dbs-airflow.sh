#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2017
#
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

PG_PORT=5432

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
# https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --host <hostname> [--port <port>] --user <username> --password <password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --host dbhost --user foo --password bar"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    echo "You must have root priviledges to run this program."
    exit 2
  fi
}

# Function to print and error message and exit.
err_msg () {
  local CODE=$1
  echo "ERROR: Could not install required package. Exiting."
  exit $CODE
}

## If the variable DEBUG is set, then turn on tracing.
## http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
#if [ $DEBUG ]; then
#  # This will turn on the ksh xtrace option for mainline code
#  set -x
#
#  # This will turn on the ksh xtrace option for all functions
#  typeset +f |
#  while read F junk
#  do
#    typeset -ft $F
#  done
#  unset F junk
#fi

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -h|--host)
      shift
      PG_HOST=$1
      ;;
    -P|--port)
      shift
      PG_PORT=$1
      ;;
    -u|--user)
      shift
      PG_USER=$1
      ;;
    -p|--password)
      shift
      export PGPASSWORD=$1
      ;;
    -H|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Script"
      echo "Version: $VERSION"
      echo "Written by: $AUTHOR"
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

# Check to see if we have the required parameters.
if [ -z "$PG_HOST" -o -z "$PG_USER" -o -z "$PGPASSWORD" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
#check_root

# main
if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
$ECHO sudo yum -y -e1 -d1 install epel-release
$ECHO sudo yum -y -e1 -d1 install postgresql apg || err_msg 4
if rpm -q apg; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
AIRFLOWDB_PASSWORD=`eval $PWCMD`
$ECHO psql -h $PG_HOST -p $PG_PORT -U $PG_USER postgres -c "CREATE ROLE airflow LOGIN ENCRYPTED PASSWORD '$AIRFLOWDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h $PG_HOST -p $PG_PORT -U $PG_USER postgres -c 'ALTER ROLE airflow SET search_path = airflow, "$user", public;'
$ECHO psql -h $PG_HOST -p $PG_PORT -U $PG_USER postgres -c "CREATE DATABASE airflow WITH OWNER = airflow ENCODING = 'UTF8' TABLESPACE = pg_default CONNECTION LIMIT = -1;"
#$ECHO psql -h $PG_HOST -p $PG_PORT -U $PG_USER postgres -c "CREATE DATABASE airflow WITH OWNER = airflow ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "airflow : $AIRFLOWDB_PASSWORD"

