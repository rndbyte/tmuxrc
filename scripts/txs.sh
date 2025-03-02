#!/usr/bin/env bash

################################################################################
#                               TmuX Sessions
#
#         The TXS is a tool for creating or switching sessions
#         in tmux by names. It can be used outside tmux to start a session.
#
################################################################################

help='false'
levels=1
name=''
recursive='false'
usage="\
TmuX Sessions

SYNOPSIS:

    txs [OPTION ...] [-h|-l|-n|-r] DIRS

OPTIONS:

    -l NUM  Descend at most levels (a non-negative integer) levels of directories below the starting-points.
    -n STR  Specify the session name

    -r      Use sub directories for selection
    -h      Show this help
"

while getopts 'rhl:n:' flag; do
    case $flag in
        r) recursive="true" ;;
        l) levels="${OPTARG}" ;;
        n) name="${OPTARG}" ;;
        *) help="true" ;;
    esac
done

shift $(($OPTIND - 1))

dirs="$@"
sub_dirs=""
session_dirs=""
selected_dir=""

if [[ "$help" = true ]]; then
    echo "$usage"
    exit 2
fi

switch_to() {
    if [[ -z $TMUX ]]; then
        tmux attach-session -t $1
    else
        tmux switch-client -t $1
    fi
}

has_session() {
    tmux list-sessions | grep -q "^$1:"
}

hydrate() {
    if [ -f $2/.txs ]; then
        tmux send-keys -t $1 "source $2/.txs" c-M
    elif [ -f $HOME/.txs ]; then
        tmux send-keys -t $1 "source $HOME/.txs" c-M
    fi
}

open_session() {
    local name=$1
    local dir=$2
    local tmux_running=$(pgrep tmux)

    if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
        tmux new-session -s $name -c $dir -e "TXS_PROJECT_DIR=\"$dir\"" -e "TXS_PROJECT_NAME=\"$name\""
        hydrate $name $dir
        exit 0
    fi

    if ! has_session $name; then
        tmux new-session -ds $name -c $dir -e "TXS_PROJECT_DIR=\"$dir\"" -e "TXS_PROJECT_NAME=\"$name\""
        hydrate $name $dir
    fi

    switch_to $name
}

log() {
    echo -e >&2 "$1"
}

test_directories() {
    for path in $*; do
        if [[ ! -d "$path" ]]; then
            log "Error: invalid directory $path"

            return 1
        fi
    done

    return 0
}

get_sub_directories() {
    for dir in $*; do
        sub_dirs="$sub_dirs "$(find "$dir" -mindepth 1 -maxdepth "$levels" -type d)
    done

    if [[ "$sub_dirs" = "" ]]; then
        return 1
    fi

    return 0
}

select_directory() {
    selected_dir=$(echo "$1" | fzf)

    if [[ "$selected_dir" = "" ]];then
        log "Error: Fzf failed to retrieve directory $dirs"

        return 1
    fi

    return 0
}

get_name() {
    if [[ "$name" = '' ]]; then
        if ! name=$(basename "$1" | tr . _); then
            log "Error: Getting basename failed, $selected_dir"

            return 1
        fi
    fi

    return 0
}

if [[ $dirs = "" ]]; then
    log "$usage"
    exit 2
fi

if [[ $recursive = false && $# = 1 ]]; then
    if ! test_directories $dirs ; then
        exit 1
    fi

    selected_dir="$dirs"

    if ! get_name $selected_dir; then
        exit 1
    fi

    open_session $name $selected_dir

    exit 0
fi

if [[ $recursive = false ]]; then
    if ! test_directories $dirs ; then
        exit 1
    fi

    if ! select_directory $dirs; then
        exit 1
    fi

    if ! get_name $selected_dir; then
        exit 1
    fi

    open_session $name $selected_dir

    exit 0
fi

if [[ $recursive = true ]]; then
    if ! test_directories $dirs ; then
        exit 1
    fi

    if ! get_sub_directories $dirs; then
        exit 1
    fi

    if ! select_directory "$sub_dirs"; then
        exit 1
    fi

    if ! get_name $selected_dir; then
        exit 1
    fi

    open_session $name $selected_dir

    exit 0
fi

exit 0
