#!/bin/bash

################################################################################
# 利用方法
#-------------------------------------------------------------------------------
# git pull & rsync
# ./deploy.sh pull-sync
#
# git pull & rsync force（cronに登録する場合も含む）
# ./deploy.sh pull-sync-force
#
#-------------------------------------------------------------------------------
# イレギュラーケース
#-------------------------------------------------------------------------------
# ディレクトリ差分を見てから同期したい場合
# ./deploy.sh sync
# ./deploy.sh pull; ./deploy.sh sync
#
# 強制的に同期したい場合
# ./deploy.sh sync-force
# ./deploy.sh pull; ./deploy.sh sync-force
#
# git pullだけ
# ./deploy.sh pull
#
# rsync のドライ実行
# ./deploy.sh dry-sync
#
# 変数の表示
# ./deploy.sh config
#
# 通知テスト
# ./deploy.sh notify-test
################################################################################

function main() {
    MODE="${1}"
    CONFIG_FILE=".deploy-config"

    if [ "${MODE}" = 'help' ]; then
        info "Usage : sh ./deploy.sh [config|dry-sync|pull|pull-sync|pull-sync-force|sync|sync-force|notify-test]"
        exit 0
    fi

    [ -f ${CONFIG_FILE} ] || abort "No such file, ${CONFIG_FILE}"

    OWNER=""
    SERVER_NAME="`hostname`"
    GIT_HOME=""
    ORIGIN=""
    DESTINATION=""
    EXCLUDE_FROM=".deploy-sync-exclude"
    EXTR_SCRIPT=""
    NOTIFY_TOOL=""
    NOTIFY_NAME=""
    source ${CONFIG_FILE}

    # Check1
    if [ "${OWNER}" = '' ]; then
        abort "Variable OWNER is undefined"
    else
        if [ "`whoami`" != ${OWNER} ]; then
            abort "OWNER is mismatching"
        fi
    fi
    # Check2
    if [ "${ORIGIN}" = '' ]; then
        abort "Variable ORIGIN is undefined"
    else
        [ -d ${ORIGIN} ] || abort "Variable ORIGIN is no such directory, ${ORIGIN}"
    fi
    # Check3
    if [ "${DESTINATION}" = '' ]; then
        abort "Variable DESTINATION is undefined"
    else
        [ -d ${DESTINATION} ] || abort "Variable DESTINATION is no such directory, ${DESTINATION}"
    fi
    # Check4
    if [ "${EXCLUDE_FROM}" = '' ]; then
        abort "Variable EXCLUDE_FROM is undefined"
    else
        [ -f ${EXCLUDE_FROM} ] || abort "Variable EXCLUDE_FROM is no such file, ${EXCLUDE_FROM}"
    fi
    # Check5
    if [ "${NOTIFY_TOOL}" != '' ]; then
        [ -f ${NOTIFY_TOOL} ] || abort "Variable NOTIFY_TOOL is no such file, ${NOTIFY_TOOL}"
    fi
    # Check6
    if [ "${EXTR_SCRIPT}" != '' ]; then
        [ -f ${EXTR_SCRIPT} ] || abort "Variable EXTR_SCRIPT is no such file, ${EXTR_SCRIPT}"
    fi
    # Check7
    if [ "${ORIGIN}" = "${DESTINATION}" ]; then
        abort "Variable ORIGIN and DESTINATION is same."
    fi
    # Check8
    if [ "${MODE}" = 'pull' ] || \
       [ "${MODE}" = 'pull-sync' ] || \
       [ "${MODE}" = 'pull-sync-force' ]; then
        if [ "${GIT_HOME}" = '' ]; then
            abort "Variable GIT_HOME is undefined"
        else
            [ -d ${GIT_HOME} ] || abort "Variable GIT_HOME is no such directory, ${GIT_HOME}"
        fi
    fi

    if [ "${MODE}" = 'config' ]; then
        echo_config
    elif [ "${MODE}" = 'dry-sync' ]; then
        dry_directory_sync
    elif [ "${MODE}" = 'pull' ]; then
        git_pull
    elif [ "${MODE}" = 'pull-sync' ]; then
        git_pull_sync 0
    elif [ "${MODE}" = 'pull-sync-force' ]; then
        git_pull_sync 1
    elif [ "${MODE}" = 'sync' ]; then
        directory_sync
    elif [ "${MODE}" = 'sync-force' ]; then
        directory_sync_force
    elif [ "${MODE}" = 'notify-test' ]; then
        notify_test
    else
        abort "Unknown mode, ${MODE}"
    fi
    execute_extra_script ${MODE}
}

function abort() {
    echo -e "\033[31m${@}\033[00m" 1>&2
    exit 1
}
function warning() {
    echo -e "\033[33m${@}\033[00m" 1>&2
}
function info() {
    echo -e "\033[32m${@}\033[00m" 1>&2
}
function highlight_start() {
    echo -en "\033[34m"
}
function highlight_end() {
    echo -en "\033[00m"
}

function echo_config() {
    highlight_start
    echo "OWNER        : ${OWNER}"
    echo "GIT_HOME     : ${GIT_HOME}"
    echo "ORIGIN       : ${ORIGIN}"
    echo "DESTINATION  : ${DESTINATION}"
    echo "EXCLUDE_FROM : ${EXCLUDE_FROM}"
    highlight_end
}
function dry_directory_sync() {
    cd ${ORIGIN}
    highlight_start

    echo "> DRY-RSYNC LOG"
    rsync -rlcvn --delete ./ "${DESTINATION}" \
        --exclude-from="${EXCLUDE_FROM}"
    echo "< DRY-RSYNC LOG"

    highlight_end
}
function git_pull() {
    cd ${GIT_HOME}
    [ -d '.git' ] || abort "Not a git repository"

    highlight_start

    echo "> PULL LOG"
    git pull
    echo "< PULL LOG"

    highlight_end
}
function git_pull_sync() {
    cd ${GIT_HOME}
    [ -d '.git' ] || abort "Not a git repository"

    cd ${ORIGIN}
    IS_QUIET=$1
    OLD_LOG="`git log --oneline -5`"
    PULL_LOG="`git pull`"
    NEW_LOG="`git log --oneline -5`"

    if [ "${IS_QUIET}" = '1' ]; then
        if [ "${OLD_LOG}" != "${NEW_LOG}" ]; then
            rsync -rlcv --delete ./ "${DESTINATION}" \
                --exclude-from="${EXCLUDE_FROM}"
        fi
    else
        highlight_start

        if [ "${OLD_LOG}" = "${NEW_LOG}" ]; then
            echo "Git was up to date."
        else
            echo "> LOG DIFF"
            diff <(echo "$OLD_LOG") <(echo "$NEW_LOG")
            echo "< LOG DIFF"
            echo ""
            echo "> PULL LOG"
            echo "${PULL_LOG}"
            echo "< PULL LOG"

            echo "Do you want to synchronize? [Y/n]"
            read ANSWER
            if [ "${ANSWER}" = "Y" ]; then
                rsync -rlcv --delete ./ "${DESTINATION}" \
                    --exclude-from="${EXCLUDE_FROM}"

                export SERVER_NAME
                export PULL_LOG
                export NEW_LOG
                export SERVICE_URL
                echo "Notify to ${NOTIFY_NAME}"
                cd ${BASE_DIRECTORY}
                ${NOTIFY_TOOL}
            fi
        fi

        highlight_end
    fi

}
function directory_sync() {
    cd ${ORIGIN}
    highlight_start

    echo "> DRY-RSYNC LOG"
    rsync -rlcvn --delete ./ "${DESTINATION}" \
        --exclude-from="${EXCLUDE_FROM}"
    echo "< DRY-RSYNC LOG"

    echo "Do you want to synchronize? [Y/n]"
    read ANSWER
    if [ "${ANSWER}" = "Y" ]; then
        rsync -rlcv --delete ./ "${DESTINATION}" \
            --exclude-from="${EXCLUDE_FROM}"
    fi

    highlight_end
}
function directory_sync_force() {
    cd ${ORIGIN}
    highlight_start

    echo "> RSYNC LOG"
    rsync -rlcv --delete ./ "${DESTINATION}" \
        --exclude-from="${EXCLUDE_FROM}"
    echo "< RSYNC LOG"

    highlight_end
}
function notify_test() {
    PULL_LOG="NOTIFY TEST"
    NEW_LOG="NOTIFY TEST"
    export SERVER_NAME
    export PULL_LOG
    export NEW_LOG
    export SERVICE_URL
    echo "Notify to ${NOTIFY_NAME}"
    cd ${BASE_DIRECTORY}
    ${NOTIFY_TOOL}
}
function execute_extra_script() {
    if [ "${EXTR_SCRIPT}" != '' ]; then
        "${EXTR_SCRIPT}" $1
    fi
}

cd "`dirname $0`"
BASE_DIRECTORY="`pwd`"
main $1
