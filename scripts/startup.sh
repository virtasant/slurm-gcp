#!/bin/bash
# Copyright (C) SchedMD LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SLURM_DIR=/slurm
FLAGFILE=$SLURM_DIR/slurm_configured_do_not_remove
SCRIPTS_DIR=$SLURM_DIR/scripts

METADATA_SERVER="metadata.google.internal"
URL="http://$METADATA_SERVER/computeMetadata/v1"
HEADER="Metadata-Flavor:Google"
CURL="curl -sS --fail --header $HEADER"

function fetch_scripts {
	# fetch project metadata
	if ! CLUSTER=$($CURL $URL/instance/attributes/slurm_cluster_name); then
		echo "ERROR: cluster name not found in instance metadata. Quitting!"
		return 1
	fi
	if ! META_DEVEL=$($CURL $URL/project/attributes/$CLUSTER-slurm-devel); then
		echo "WARNING: $CLUSTER-slurm-devel not found in project metadata, skipping script update"
		return
	fi
	echo devel data found in project metadata, looking to update scripts
	if STARTUP_SCRIPT=$(jq -re '."startup-script"' <<< "$META_DEVEL"); then
		echo "INFO: updating startup.sh from project metadata"
		printf '%s' "$STARTUP_SCRIPT" > $STARTUP_SCRIPT_FILE
	else
		echo "WARNING: startup-script not found in project metadata, skipping update"
	fi
	if SETUP_SCRIPT=$(jq -re '."setup-script"' <<< "$META_DEVEL"); then
		echo "INFO: updating setup.py from project metadata"
		printf '%s' "$SETUP_SCRIPT" > $SETUP_SCRIPT_FILE
	else
		echo "WARNING: setup-script not found in project metadata, skipping update"
	fi
	if UTIL_SCRIPT=$(jq -re '."util-script"' <<< "$META_DEVEL"); then
		echo "INFO: updating util.py from project metadata"
		printf '%s' "$UTIL_SCRIPT" > $UTIL_SCRIPT_FILE
	else
		echo "WARNING: util-script not found in project metadata, skipping update"
	fi
	if RESUME_SCRIPT=$(jq -re '."slurm-resume"' <<< "$META_DEVEL"); then
		echo "INFO: updating resume.py from project metadata"
		printf '%s' "$RESUME_SCRIPT" > $RESUME_SCRIPT_FILE
	else
		echo "WARNING: slurm-resume not found in project metadata, skipping update"
	fi
	if SUSPEND_SCRIPT=$(jq -re '."slurm-suspend"' <<< "$META_DEVEL"); then
		echo "INFO: updating suspend.py from project metadata"
		printf '%s' "$SUSPEND_SCRIPT" > $SUSPEND_SCRIPT_FILE
	else
		echo "WARNING: slurm-suspend not found in project metadata, skipping update"
	fi
	if SLURMSYNC_SCRIPT=$(jq -re '."slurmsync"' <<< "$META_DEVEL"); then
		echo "INFO: updating slurmsync.py from project metadata"
		printf '%s' "$SLURMSYNC_SCRIPT" > $SLURMSYNC_SCRIPT_FILE
	else
		echo "WARNING: slurmsync not found in project metadata, skipping update"
	fi
	if SLURMEVENTD_SCRIPT=$(jq -re '."slurmeventd"' <<< "$META_DEVEL"); then
		echo "INFO: updating slurmeventd.py from project metadata"
		printf '%s' "$SLURMEVENTD_SCRIPT" > $SLURMEVENTD_SCRIPT_FILE
	else
		echo "WARNING: slurmeventd not found in project metadata, skipping update"
	fi
}

PING_METADATA="ping -q -w1 -c1 $METADATA_SERVER"
echo "INFO: $PING_METADATA"
for i in $(seq 10); do
    [ $i -gt 1 ] && sleep 5;
    $PING_METADATA > /dev/null && s=0 && break || s=$?;
    echo "ERROR: Failed to contact metadata server, will retry"
done
if [ $s -ne 0 ]; then
    echo "ERROR: Unable to contact metadata server, aborting"
    wall -n '*** Slurm setup failed in the startup script! see `journalctl -u google-startup-scripts` ***'
    exit 1
else
    echo "INFO: Successfully contacted metadata server"
fi

GOOGLE_DNS=8.8.8.8
PING_GOOGLE="ping -q -w1 -c1 $GOOGLE_DNS"
echo "INFO: $PING_GOOGLE"
for i in $(seq 5); do
    [ $i -gt 1 ] && sleep 2;
    $PING_GOOGLE > /dev/null && s=0 && break || s=$?;
	echo "failed to ping Google DNS, will retry"
done
if [ $s -ne 0 ]; then
    echo "WARNING: No internet access detected"
else
    echo "INFO: Internet access detected"
fi

mkdir -p $SCRIPTS_DIR

STARTUP_SCRIPT_FILE=$SCRIPTS_DIR/startup.sh
SETUP_SCRIPT_FILE=$SCRIPTS_DIR/setup.py
UTIL_SCRIPT_FILE=$SCRIPTS_DIR/util.py
RESUME_SCRIPT_FILE=$SCRIPTS_DIR/resume.py
SUSPEND_SCRIPT_FILE=$SCRIPTS_DIR/suspend.py
SLURMSYNC_SCRIPT_FILE=$SCRIPTS_DIR/slurmsync.py
SLURMEVENTD_SCRIPT_FILE=$SCRIPTS_DIR/slurmeventd.py
fetch_scripts

if [ -f $FLAGFILE ]; then
	echo "WARNING: Slurm was previously configured, quitting"
	exit 0
fi
touch $FLAGFILE

function fetch_feature {
	if slurmd_feature="$($CURL $URL/instance/attributes/slurmd_feature)"; then
		echo "$slurmd_feature"
	else
		echo ""
	fi
}
SLURMD_FEATURE="$(fetch_feature)"

echo "INFO: Running python cluster setup script"
chmod +x $SETUP_SCRIPT_FILE
python3 $SCRIPTS_DIR/util.py
if [[ -n "$SLURMD_FEATURE" ]]; then
	echo "INFO: Running dynamic node setup."
	exec $SETUP_SCRIPT_FILE --slurmd-feature="$SLURMD_FEATURE"
else
	exec $SETUP_SCRIPT_FILE
fi
