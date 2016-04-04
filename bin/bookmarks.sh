#!/bin/bash
#{{{
# Copyright (c) 2015, Michael Brailsford, http://www.github.com/brailsmt
# Copyright (c) 2010, Huy Nguyen, http://www.huyng.com
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided 
# that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, this list of conditions 
#       and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#       following disclaimer in the documentation and/or other materials provided with the distribution.
#     * Neither the name of Huy Nguyen nor the names of contributors
#       may be used to endorse or promote products derived from this software without 
#       specific prior written permission.
#       
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.


# USAGE:  This defines a few shell functions that enhance the CLI by providing bookmarks for directories.
# cdg - Use this command to go to a bookmarked directory.  The mnemonic for g is to 'go' to a bookmark.
#       If a bookmark name is supplied, then change to that directory, otherwise display menu of all bookmarks.
#
# cdc - Create a bookmark at the current working directory.  If a bookmark name is provided, it will be used as the
#       name of the bookmark, otherwise the name of the current working directory is used (literally:  basename `pwd`)
#
# cdl - List all bookmarks currently set.
#
# cdd - Delete a bookmark
#}}}

if [[ -v BOOKMARKS_FUZZY_COMPLETE && $(which fzf > /dev/null) -ne 0 ]]; then
    >&2 echo "Cannot use fuzzy completion without fzf installed and on \$PATH"
    >&2 echo "Reverting to non-fuzzy completion"
    unset BOOKMARKS_FUZZY_COMPLETE
fi
if [[ -v BOOKMARKS_FUZZY_MENU && $(which fzf > /dev/null) -ne 0 ]]; then
    >&2 echo "Cannot use fuzzy menu without fzf installed and on \$PATH"
    >&2 echo "Reverting to non-fuzzy menu"
    unset BOOKMARKS_FUZZY_MENU
fi

RED="\033[0;31m"
GREEN="\033[0;33m"
RESET_COLOR="\033[00m"

# setup file to store bookmarks
function bookmark_check {
    if [[ ! -v BOOKMARKS_FILE ]]; then
        export BOOKMARKS_FILE="$HOME/.dirbookmarks"
    fi

    if [[ -v BOOKMARK ]]; then
        unset BOOKMARK
    fi
    declare -A BOOKMARK
}
bookmark_check

# create a bookmark at the cwd
function cdc {
    bookmark_check
    bookmark_name=${@:-$(basename $PWD)}
    
    if _bookmark_name_valid $bookmark_name; then
        remove_bookmark $bookmark_name
        echo "BOOKMARK[$bookmark_name]=$PWD" >> $BOOKMARKS_FILE
    fi
}

# list bookmarks
function cdl {
    local max_bookmark_len=35
    bookmark_check
    if [[ -s $BOOKMARKS_FILE ]]; then
        source $BOOKMARKS_FILE
        echo
        printf "%-${max_bookmark_len}s %s\n" "Bookmark Name" "| Path"
        printf "%${max_bookmark_len}s-+------------------\n" | tr ' ' '-'
        for bookmark in ${!BOOKMARK[@]}; do
            printf "$GREEN%-${max_bookmark_len}s $RESET_COLOR| %s" $bookmark ${BOOKMARK[$bookmark]}
            echo
        done
        echo
    else
        echo -e "${RED}ERROR: $BOOKMARKS_FILE does not exist$RESET_COLOR"
    fi
}

function menu_cdg {
    bookmark_check
    source $BOOKMARKS_FILE
    echo "Select bookmark from the list:  "

    declare -A menu_choices
    opt=1
    for bookmark in "${!BOOKMARK[@]}"; do
        printf "%d)  $GREEN%-20s $RESET_COLOR ( %s )\n" $opt $bookmark ${BOOKMARK[$bookmark]}
        menu_choices[$opt]=$bookmark
        ((opt+=1))
    done
    
    local choice
    read -p "bookmark number (q to quit): " choice

    if [[ -z $choice || 'q' == $choice ]]; then
        return
    fi

    bookmark=''
    for c in ${!menu_choices[@]}; do
        if [[ $choice == $c ]]; then
            bookmark=${menu_choices[$choice]}
        fi
    done

    if [[ -n $bookmark ]]; then
        cd ${BOOKMARK[$bookmark]}
    else
        echo "Unrecognized input"
    fi
}

# display a menu enabled with fuzzy search, if a parameter is provided, the menu will be prepopulated with selections
# that match $1
function menu_cdg_fzf {
    local menu_choices opt
    bookmark_check
    source $BOOKMARKS_FILE

    declare -a menu_choices
    for bookmark in "${!BOOKMARK[@]}"; do
        printf -v opt "$GREEN%-30s $RESET_COLOR ( %s )\n" $bookmark ${BOOKMARK[$bookmark]}
        menu_choices+=$opt
    done

    local choice
    if [[ -n $1 ]]; then
        choice=$(echo "$menu_choices" | fzf -1 --cycle --ansi --query="$1" | gawk '{print $3}')
    else
        choice=$(echo "$menu_choices" | fzf -1 --cycle --ansi | gawk '{print $3}')
    fi

    if [[ -n $choice ]]; then
        cd $choice
    else
        echo -e "${RED}WARNING: '${1}' bookmark does not exist$RESET_COLOR"
    fi
}

# jump to bookmark
function cdg {
    bookmark_check
    if [[ $# -eq 0 ]]; then
        if [[ -v BOOKMARKS_FUZZY_MENU ]]; then
            menu_cdg_fzf
        else
            menu_cdg
        fi
        return $?
    fi

    if [[ -s $BOOKMARKS_FILE ]]; then
        source $BOOKMARKS_FILE
        if [[ -n $1 && -d ${BOOKMARK[$1]} ]]; then
            cd ${BOOKMARK[$1]}
        else
            menu_cdg_fzf $@
        fi
    else
        echo -e "${RED}ERROR: $BOOKMARKS_FILE does not exist$RESET_COLOR"
    fi
}

# delete bookmark
function cdd {
    
    bookmark_check
    if _bookmark_name_valid $1; then
        remove_bookmark $1
    fi
}

# print out help for the forgetful
function cdh {
    echo
    echo 'cdh        - Display this help'
    echo 'cdc [name] - Create a bookmark for the current directory'
    echo 'cdg [name] - Change to (Go to) the directory associated with "name"'
    echo 'cdd [name] - Deletes the bookmark'
    echo 'cdl        - Lists all available bookmarks'
    echo
    echo 'For cdc and cdd if a bookmark name is omitted, the name of the current'
    echo 'working directory (`basename $PWD`) will be used as the bookmark_name.'
    echo
    echo 'For cdg without a bookmark name will list the bookmarks in a menu.'
}

# list bookmarks without dirname
function _l {
    source $BOOKMARKS_FILE
    echo ${!BOOKMARK[@]}
}

# validate bookmark name
function _bookmark_name_valid {
    if $(echo $1 | grep -q -v '[A-Za-z0-9_]'); then
        echo $1
        echo "Valid bookmark name is required!"
        return 1
    fi
    return 0
}

# completion command
function _dirbookmark_complete {
    local curw
    COMPREPLY=()
    curw=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W '`_l`' -- $curw))
    return 0
}

# fuzzy completion command
function _fzf_dirbookmark_complete {
    source $BOOKMARKS_FILE
    local cur bookmarks
    cur=${COMP_WORDS[$COMP_CWORD]}

    bookmarks=$(echo ${!BOOKMARK[@]} | tr ' ' '\n')
    COMPREPLY=($(echo "$bookmarks" | fzf -1 -f $cur | tr '\n' ' '))
    return 0
}

# safe delete line from $BOOKMARKS_FILE
function remove_bookmark {
    if [[ -s $BOOKMARKS_FILE ]]; then
        # purge line
        sed -i.bak "/^BOOKMARK\[$1\]/d" $BOOKMARKS_FILE
        unset BOOKMARK[$1]
        return 0
    fi
    return 0
}

# bind completion command for g,p,d to _dirbookmark_complete
shopt -s progcomp
if [[ -v BOOKMARKS_FUZZY_COMPLETE ]]; then
    complete -F _fzf_dirbookmark_complete cdg
    complete -F _fzf_dirbookmark_complete cdp
    complete -F _fzf_dirbookmark_complete cdd
else
    complete -F _dirbookmark_complete cdg
    complete -F _dirbookmark_complete cdp
    complete -F _dirbookmark_complete cdd
fi
#complete -o default -F _fzf_dirbookmark_complete cd
