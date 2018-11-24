#!/usr/bin/env bash

set -o nounset
set -o pipefail

# Make sure we always have a healthcheck URL variable empty unless specified
: ${RCLONE_CROND_HEALTHCHECK_URL:=""}

#---------------------------------------------------------------------
# configure crond
#---------------------------------------------------------------------

function crond() {

if [[ -n "${RCLONE_CROND_SOURCE_PATH:-}" ]] || [[ -n "${RCLONE_CROND_DESTINATION_PATH:-}" ]]; then

    # Create the environment file for crond
    if [[ ! -d /cron ]]; then mkdir -p /cron; fi

    # Create the environment file for crond
    printenv | sed 's/^\([a-zA-Z0-9_]*\)=\(.*\)$/export \1="\2"/g' | grep -E "^export RCLONE" > /cron/rclone.env
    if [[ ! -f /cron/rclone.env ]]; then exit 1; fi

    # Set a default if a schedule is not present
    if [[ -z "${RCLONE_CROND_SCHEDULE:-}" ]]; then RCLONE_CROND_SCHEDULE="0 0 * * *" && export RCLONE_CROND_SCHEDULE; fi

    if [[ -z ${RCLONE_CROND_HEALTHCHECK_URL:-} ]]; then
      {
        echo 'SHELL=/bin/bash'
        echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        echo '${RCLONE_CROND_SCHEDULE} /usr/bin/env bash -c "/rclone.sh run" 2>&1'
      } | tee /cron/crontab.conf
    else
      {
        echo 'SHELL=/bin/bash'
        echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        echo '${RCLONE_CROND_SCHEDULE} /usr/bin/env bash -c "/rclone.sh run" && curl -fsS --retry 3'
        echo '${RCLONE_CROND_HEALTHCHECK_URL} > /dev/null'
      } | tee /cron/crontab.conf
    fi

    if [[ ! -f /cron/crontab.conf ]]; then exit 1; fi
    # Add the crond config
    cat /cron/crontab.conf | crontab - && crontab -l
    # Start crond
    runcrond="crond -b" && bash -c "${runcrond}"
fi

}

#---------------------------------------------------------------------
# configure monit
#---------------------------------------------------------------------

function monit() {

  # Create monit config
  {
      echo 'set daemon 10'
      echo 'set pidfile /var/run/monit.pid'
      echo 'set statefile /var/run/monit.state'
      echo 'set httpd port 2849 and'
      echo '    use address localhost'
      echo '    allow localhost'
      echo 'set logfile syslog'
      echo 'set eventqueue'
      echo '    basedir /var/run'
      echo '    slots 100'
      echo 'include /etc/monit.d/*'

  } | tee /etc/monitrc

chmod 700 /etc/monitrc
run="monit -c /etc/monitrc" && bash -c "${run}"

}

#---------------------------------------------------------------------
# run services
#---------------------------------------------------------------------

function run() {
	if [[ ! -z "${RCLONE_CROND_SCHEDULE:-}" ]]; then
		monit
	fi
}

run
exec "$@"
