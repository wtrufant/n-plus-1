#! /bin/bash

# This is set to run from wherever you clone this repo.  /backup seems best.
# sudo mkdir /backups; sudo chmod 700 /backups; sudo git clone https://github.com/wtrufant/n-plus-1.git /backups

: << CONFIG_FILE
#! /bin/bash

#### Common
MAX_D=3 # Max days
MAX_W=3 # Max weeks
MAX_M=3 # Max months


#### MariaDB
export TAR_PWD='TAR PW HASH HERE' # openssl passwd -6

# Variables for MariaDB Backups
export MYSQL_PWD='DB PW HERE' # https://mariadb.com/kb/en/mariadb-environment-variables/


#### NextCloud


#### Users
USERS=(primaryuser root)

#### WWW


CONFIG_FILE

# shellcheck source=/dev/null
source /root/.config/n-plus-1
# Should probably do user detetection or "${SUDO_USER:-${USER}}" or something. But, it's likely root.

BASEDIR="$(dirname "$0")"
BK_DATE="$(date +%Y%m%d_%H%M)"
MAX_D=$((MAX_D - 1))
MAX_W=$((MAX_W * 7 - 1))
MAX_M=$((MAX_M * 30 - 1))

# TODO: Move the tarring out of the function.  For things like NC, it's a lot less to do.

function backups() {
	shopt -s dotglob
	# tar file pattern: * .??*
	tar -C "${BASEDIR}/$1/daily/${BK_DATE}" -czf "${BASEDIR}/$1/daily/${BK_DATE}.tgz" .
	rm -rf "${BASEDIR:?}/$1/daily/${BK_DATE}"
	shopt -u dotglob

	# Clean old dailies every day.
	if [ "$(find "${BASEDIR}/$1/daily" -type f -name "*.tgz" | wc -l)" -gt "${MAX_D}" ]; then
		find "${BASEDIR}/$1/daily" -type f -name "*.tgz" -mtime "+${MAX_D}" -delete
	fi

	# Clean old weeklies on Sunday.
	if [ "$(date +%u)" == "7" ]; then
		cp "${BASEDIR}/$1/daily/${BK_DATE}.tgz" "${BASEDIR}/$1/weekly/${BK_DATE}.tgz"
		if [ "$(find "${BASEDIR}/$1/weekly" -type f -name "*.tgz" | wc -l)" -gt "${MAX_W}" ]; then
			find "${BASEDIR}/$1/weekly" -type f -name "*.tgz" -mtime "+${MAX_W}" -delete
		fi
	fi

	# Clean old montlies on the first of the month.
	if [ "$(date +%d)" == "01" ]; then
		cp "${BASEDIR}/$1/daily/${BK_DATE}.tgz" "${BASEDIR}/$1/monthly/${BK_DATE}.tgz"
		if [ "$(find "${BASEDIR}/$1/monthly" -type f -name "*.tgz" | wc -l)" -gt "${MAX_M}" ]; then
			find "${BASEDIR}/$1/monthly" -type f -name "*.tgz" -mtime "+${MAX_M}" -delete
		fi
	fi

	rclone sync "/backups/$1" "b2-wt3-callio:wt3-callio/$1"

}

if [ ! -f /root/.config/n-plus-1 ] || [ -z "${MYSQL_PWD}" ] || [ -z "${TAR_PWD}" ]; then exit 1; fi


#### MariaDB
mariadb-backup --backup --target-dir="${BASEDIR}/mariadb/daily/${BK_DATE}" > /dev/null 2>&1 || { rm -rf "${BASEDIR:?}/mariadb/daily/${BK_DATE}"; echo "MariaDB Backup failed."; exit 1; }
backups mariadb


#### System
cp -a /etc "${BASEDIR}/system/daily/${BK_DATE}/"

# Get a list of installed packages:
if [ -f /usr/bin/dpkg ]; then dpkg -l | grep '^ii' > "${BASEDIR}/system/daily/${BK_DATE}/dpkg.txt"; fi
if [ -f /usr/bin/flatpak ]; then flatpak list | sort > "${BASEDIR}/system/daily/${BK_DATE}/flatpak.txt"; fi
if [ -f /usr/bin/pacman ]; then pacman -Q > "${BASEDIR}/system/daily/${BK_DATE}/pacman.txt"; fi
if [ -f /usr/bin/rpm ]; then rpm -qa | sort > "${BASEDIR}/system/daily/${BK_DATE}/rpm.txt"; fi
if [ -f /usr/bin/snap ]; then snap list > "${BASEDIR}/system/daily/${BK_DATE}/snap.txt"; fi

backups system


### NextCloud
: << NC

Excludes: files_versions, files_trashbin

alias occ='sudo -u apache php /data/www/io/https/occ'
output=$($cmd)
https://help.nextcloud.com/t/how-to-manually-delete-older-file-versions/26353/4
--- /data/www/io/https/data/myuser/files_versions -----------------------
                                  /..
    9.4 GiB [###################] /Music
  567.5 MiB [#                  ] /RPG

--- /data/www/io/https/data/myuser/files_trashbin -----------------------
                                  /..
    2.7 GiB [###################] /files
  178.1 MiB [#                  ] /versions
e 512.0   B [                   ] /keys
NC


##### Users ( set as array in .config file )
# exclude: VMs, snap, .local/share/Steam, .cache, 


#### WWW


