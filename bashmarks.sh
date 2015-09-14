#!/bin/bash
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


# USAGE: 
# s bookmarkname - saves the curr dir as bookmarkname
# g bookmarkname - jumps to the that bookmark
# g b[TAB] - tab completion is available
# p bookmarkname - prints the bookmark
# p b[TAB] - tab completion is available
# d bookmarkname - deletes the bookmark
# d [TAB] - tab completion is available
# l - list all bookmarks

RED="\033[0;31m"
GREEN="\033[0;33m"
RESET_COLOR="\033[00m"

# setup file to store bookmarks
function bookmark_check {
    if [[ ! -v $BOOKMARKS_FILE ]]; then
        export BOOKMARKS_FILE="$HOME/.dirbookmarks"
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
    bookmark_check
    if [[ -s $BOOKMARKS_FILE ]]; then
        source $BOOKMARKS_FILE
        echo
        printf "%-20s %s\n" "Bookmark Name" "| Path"
        echo "---------------------+------------------"
        for bookmark in ${!BOOKMARK[@]}; do
            printf "$GREEN%-20s $RESET_COLOR| %s" $bookmark ${BOOKMARK[$bookmark]}
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

# jump to bookmark
function cdg {
    bookmark_check
    if [[ $# -eq 0 ]]; then
        menu_cdg
        return $?
    fi

    if [[ -s $BOOKMARKS_FILE ]]; then
        source $BOOKMARKS_FILE
        if [[ -n $1 && -d $1 && -e $1 ]]; then
            cd $1
        else
            echo -e "${RED}WARNING: '${1}' bookmark does not exist$RESET_COLOR"
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
    echo 'cdc [name] - Create a bookmark for the current directory'
    echo 'cdg [name] - Change to (Go to) the directory associated with "name"'
    echo 'cdd [name] - Deletes the bookmark'
    echo 'cdl        - Lists all available bookmarks'
    echo
    echo 'For cdc and cdg if a bookmark name is omitted, the name of the current'
    echo 'working directory (`basename $PWD`) will be used as the bookmark_name.'
    echo
    echo 'For cdg without a bookmark name will list the bookmarks in a menu.'
}

# list bookmarks without dirname
function _l {
    source $BOOKMARKS_FILE
    env | grep "^DIR_" | cut -c5- | sort | grep "^.*=" | cut -f1 -d "=" 
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
function _comp {
    local curw
    COMPREPLY=()
    curw=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W '`_l`' -- $curw))
    return 0
}

# ZSH completion command
function _compzsh {
    reply=($(_l))
}

# safe delete line from sdirs
function remove_bookmark {
    if [[ -s $BOOKMARKS_FILE ]]; then
        # purge line
        sed -i.bak "/^BOOKMARK\[$1\]/d" $BOOKMARKS_FILE
        unset BOOKMARK[$1]
        return 0
    fi
    return 0
}

# bind completion command for g,p,d to _comp
if [ $ZSH_VERSION ]; then
    compctl -K _compzsh g
    compctl -K _compzsh p
    compctl -K _compzsh d
else
    shopt -s progcomp
    complete -F _comp cdg
    complete -F _comp cdp
    complete -F _comp cdd
fi
