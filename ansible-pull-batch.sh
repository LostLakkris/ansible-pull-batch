#!/bin/sh
usage()
{
	echo "USAGE:"
	echo "  $0 list.csv"
	echo
	echo "CSV FORMAT:"
	echo "  ## Prefix comments w/ #, anything in '[]' is optional, but still positional"
	echo "  #url,[branch],[local.yml],[absolute localdir],[absolute pemfile]"
	echo
	echo "NOTES:"
	echo "  pemfile options only work if URL begins with ssh://"
}
if [ -z "$@" ]; then
	usage
	echo "No arguments provided"
	exit 1
fi
if [ ! -e "$@" ]; then
	usage
	echo "Config file '$@' not found."
	exit 1
fi

OIFS=$IFS
IFS=$'\n'
OGIT_SSH_COMMAND=${GIT_SSH_COMMAND}
export ANSIBLE_NOCOWS=1 # Disable cowsay
for entry in $(awk '!/^#/{print}' "${@}"); do
	# Parse entry
	URL=$(echo "${entry}" | awk -F',' '{print $1}')
	TYPE=$(echo "${URL}" | awk -F ':' '{print $1}')

	BRANCH=$(echo "${entry}" | awk -F',' '{print $2}')
	if [ -z "${BRANCH}" ]; then
		BRANCH="master"
	fi

	YML_FILE=$(echo "${entry}" | awk -F',' '{print $3}')

	LOCALDIR=$(echo "${entry}" | awk -F',' '{print $4}')
	if [ -z "${LOCALDIR}" ]; then
		LOCALDIR="/playbooks/$(echo "${URL}" | awk -F'/' '{print $NF}')"
	fi

	PEMFILE=$(echo "${entry}" | awk -F',' '{print $5}')

	# Do stuff
	if [ ! -d "${LOCALDIR}" ]; then
		mkdir -p $(dirname "${LOCALDIR}")
	fi
	if [ "${TYPE}" == "ssh" ] && [ -n "${PEMFILE}" ]; then
		export GIT_SSH_COMMAND="ssh -i ${PEMFILE} -F /dev/null -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null'"
	else
		export GIT_SSH_COMMAND=${OGIT_SSH_COMMAND}
	fi
	if [[ -n "${YML_FILE}" ]]; then
		## Use explicitly defined yaml file
		ansible-pull --accept-host-key --clean --only-if-changed --checkout=${BRANCH} --directory=${LOCALDIR} --url=${URL} "${YML_FILE}" 2>&1
	else
		## Allow ansible-pull to follow default behavior
		ansible-pull --accept-host-key --clean --only-if-changed --checkout=${BRANCH} --directory=${LOCALDIR} --url=${URL} 2>&1
	fi
done
IFS=$OIFS
