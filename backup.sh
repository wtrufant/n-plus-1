#! /bin/bash

# This is set to run from wherever you clone this repo.  /backups seems best.
# git clone https://github.com/wtrufant/n-plus-1.git /backups; chmod 700 /backups

# You can't hide secrets from the future with math.  https://youtu.be/yVm8oZx9WSM

#TODO:
# Logging
# tar user dir exclusions, by user.
# array to set "modules" to run via argument? or all by default?

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

	# Clean old dailies every day, if we have more than the max.
	if [ "$(find "${BASEDIR}/$1/daily" -type f -name "*.tgz" | wc -l)" -gt "${MAX_D}" ]; then
		find "${BASEDIR}/$1/daily" -type f -name "*.tgz" -mtime "+${MAX_D}" -delete
	fi

	# Clean old weeklies on Sunday, if we have more than the max.
	if [ "$(date +%u)" == "7" ]; then
		if [ ! -d "${BASEDIR}/$1/weekly" ]; then mkdir "${BASEDIR}/$1/weekly"; fi
		cp "${BASEDIR}/$1/daily/${BK_DATE}.tgz" "${BASEDIR}/$1/weekly/${BK_DATE}.tgz"
		if [ "$(find "${BASEDIR}/$1/weekly" -type f -name "*.tgz" | wc -l)" -gt "${MAX_W}" ]; then
			find "${BASEDIR}/$1/weekly" -type f -name "*.tgz" -mtime "+${MAX_W}" -delete
		fi
	fi

	# Clean old montlies on the first of the month, if we have more than the max.
	if [ "$(date +%d)" == "01" ]; then
		if [ ! -d "${BASEDIR}/$1/monthly" ]; then mkdir "${BASEDIR}/$1/monthly"; fi
		cp "${BASEDIR}/$1/daily/${BK_DATE}.tgz" "${BASEDIR}/$1/monthly/${BK_DATE}.tgz"
		if [ "$(find "${BASEDIR}/$1/monthly" -type f -name "*.tgz" | wc -l)" -gt "${MAX_M}" ]; then
			find "${BASEDIR}/$1/monthly" -type f -name "*.tgz" -mtime "+${MAX_M}" -delete
		fi
	fi

	rclone sync "${BASEDIR}/$1" "${REMOTE}:${BUCKET}/$1"

}

# Bash includes filenames beginning with a '.' in the results of filename expansion. The filenames . and .. must always be matched explicitly, even if dotglob is set. 
shopt -s dotglob


#### MariaDB
if [ ! -d "${BASEDIR}/mariadb/daily" ]; then mkdir -p "${BASEDIR}/mariadb/daily"; fi
mariadb-backup --backup --target-dir="${BASEDIR}/mariadb/daily/${BK_DATE}" > /dev/null 2>&1 || { rm -rf "${BASEDIR:?}/mariadb/daily/${BK_DATE}"; echo "MariaDB Backup failed."; exit 1; }
tar -C "${BASEDIR}/mariadb/daily/${BK_DATE}" -czf "${BASEDIR}/mariadb/daily/mariadb-${BK_DATE}.tgz" .
rm -rf "${BASEDIR:?}/mariadb/daily/${BK_DATE}"
backups mariadb


#### System
if [ ! -d "${BASEDIR}/system/daily" ]; then mkdir -p "${BASEDIR}/system/daily"; fi

# Get a list of installed packages:
if [ -f /usr/bin/dpkg ]; then dpkg -l | grep '^ii' > "/etc/pkgs-dpkg.txt"; fi
if [ -f /usr/bin/flatpak ]; then flatpak list | sort > "/etc/pkgs-flatpak.txt"; fi
if [ -f /usr/bin/pacman ]; then pacman -Q > "/etc/pkgs-pacman.txt"; fi
if [ -f /usr/bin/rpm ]; then rpm -qa | sort > "/etc/pkgs-rpm.txt"; fi
if [ -f /usr/bin/snap ]; then snap list > "/etc/pkgs-snap.txt"; fi

tar -C "/etc" -czf "${BASEDIR}/system/daily/etc-${BK_DATE}.tgz" .
# /usr/local/bin ?
backups system


##### Users ( set as array in .config file )
if [ ! -d "${BASEDIR}/users/daily" ]; then mkdir -p "${BASEDIR}/users/daily"; fi
# --exclude=pattern : VMs, snap, .local/share/Steam, .cache
for U in "${USERS[@]}"; do
	USERDIR="/${U}"
	if [ "${U}" != "root" ]; then USERDIR="/home${USERDIR}"; fi
	tar -C "${USERDIR}" --exclude="${USER_EXCL}" -czf "${BASEDIR}/users/daily/${U}-${BK_DATE}.tgz" .
done
backups users

#### WWW


### NextCloud
if [ ! -d "${BASEDIR}/nextcloud/daily" ]; then mkdir -p "${BASEDIR}/nextcloud/daily"; fi

sudo -E -u "${NC_USER}" php "${NC_PATH}/occ" -q maintenance:mode --on
tar -C "${NC_PATH}" --exclude="${NC_EXCL}" -czf "${BASEDIR}/nextcloud/daily/nextcloud-${BK_DATE}.tgz" .
sudo -E -u "${NC_USER}" php "${NC_PATH}/occ" -q maintenance:mode --off
backups nextcloud
