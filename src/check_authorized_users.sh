#!/bin/bash

# This script is used to verify whether the GitHub actor
# who opened a pull request is authorized to modify
# changed model-output directories.
#
# Check user provided arguments
if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <CHANGED_DIRS> <ACTOR> [AUTHORIZED_USERS_FILE]"
	echo "  <CHANGED_DIRS>         : Space separated list of modified directories in model-output/"
	echo "  <ACTOR>                : GH username triggering the action"
	echo "  [AUTHORIZED_USERS_FILE]: Optional. Path to the file containing authorized users (defaults to 'auxiliary-data/authorized_users.txt')"
	exit 1
fi

AUTHORIZED_USERS_FILE=${3:-"auxiliary-data/authorized_users.txt"}
CHANGED_DIRS=$1
ACTOR=$2

declare -A dir_users_map
authorized_dirs=()

while IFS= read -r line; do
	read -r dir user_list <<<$line
	authorized_dirs+=($dir)
	dir_users_map[$dir]=$user_list
done <$AUTHORIZED_USERS_FILE

is_authorized=false

#Assumes CHANGED_DIR is an array
for dir in ${CHANGED_DIRS[@]}; do
	dir_found=false

	for auth_dir in ${authorized_dirs[@]}; do

		if [[ $dir == $auth_dir ]]; then
			dir_found=true
			user_list=${dir_users_map[$auth_dir]}

			if [[ $user_list == "NA" ]]; then
				echo "Error: Changes found in '$auth_dir/', but no authorized users listed."
				exit 1
			fi

			IFS=', ' read -r -a user_array <<<$user_list
			user_authorized=false
			for user in ${user_array[@]}; do
				if [[ $ACTOR == $user ]]; then
					user_authorized=true
					break
				fi
			done

			if [[ $user_authorized != true ]]; then
				echo "Error: Only the following users can modify '$auth_dir/': ${user_array[*]}"
				exit 1
			fi

		fi
	done
	if [[ $dir_found != true ]]; then
		echo "Error: Directory '$dir' is not authorized for changes."
		exit 1
	fi
done

if [[ $user_authorized == true ]]; then
	echo "Success: changes in '$dir' authorized for user '$ACTOR'."
	echo "success" >status
fi
