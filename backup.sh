#! /bin/bash

# This is set to run from wherever you clone this repo.  /backups seems best.
# git clone https://github.com/wtrufant/n-plus-1.git /backups; chmod 700 /backups

# You can't hide secrets from the future with math.  https://youtu.be/yVm8oZx9WSM

#TODOS:
# - Logging

BASEDIR="$(dirname "$0")"

# shellcheck source=/dev/null
source "${BASEDIR}/.config" || exit 1
# Should probably do user detetection or "${SUDO_USER:-${USER}}" or something. But, it's likely root.

# Generate date stamp, and calculate the max day values.  We subtract 1 due to how `find` handles values.
BK_DATE="$(date +%Y%m%d_%H%M)"
MAX_D=$((MAX_D - 1))
MAX_W=$((MAX_W * 7 - 1))
MAX_M=$((MAX_M * 30 - 1))

# TODO: Move the tarring out of the function.  For things like NC, it's a lot less to do.

function backups() {

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

	rclone sync "/backups/$1" "${REMOTE}:${BUCKET}/$1"

}

# Bash includes filenames beginning with a '.' in the results of filename expansion. The filenames . and .. must always be matched explicitly, even if dotglob is set. 
shopt -s dotglob


#### MariaDB
mariadb-backup --backup --target-dir="${BASEDIR}/mariadb/daily/${BK_DATE}" > /dev/null 2>&1 || { rm -rf "${BASEDIR:?}/mariadb/daily/${BK_DATE}"; echo "MariaDB Backup failed."; exit 1; }
tar -C "${BASEDIR}/mariadb/daily/${BK_DATE}" -czf "${BASEDIR}/mariadb/daily/${BK_DATE}.tgz" .
rm -rf "${BASEDIR:?}/mariadb/daily/${BK_DATE}"
backups mariadb


#### System
# Get a list of installed packages:
if [ -f /usr/bin/dpkg ]; then dpkg -l | grep '^ii' > "/etc/pkgs-dpkg.txt"; fi
if [ -f /usr/bin/flatpak ]; then flatpak list | sort > "/etc/pkgs-flatpak.txt"; fi
if [ -f /usr/bin/pacman ]; then pacman -Q > "/etc/pkgs-pacman.txt"; fi
if [ -f /usr/bin/rpm ]; then rpm -qa | sort > "/etc/pkgs-rpm.txt"; fi
if [ -f /usr/bin/snap ]; then snap list > "/etc/pkgs-snap.txt"; fi

tar -C "/etc" -czf "${BASEDIR}/system/daily/${BK_DATE}.tgz" .
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
# exclude: VMs, snap, .local/share/Steam, .cache


#### WWW


