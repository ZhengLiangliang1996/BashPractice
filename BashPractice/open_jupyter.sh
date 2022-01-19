#! /bin/sh
#
# template.sh
# Copyright (C) 2021 liangliang <liangliang@Liangliangs-Air.localdomain>
#
# Distributed under terms of the MIT license.
#

# Action to take when occuring ERR 
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion 
    trap - ERR 

    # consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail 

    # Validate provided exit code 
    if [[ ${1-} =~ ^[0-9]+$ ]]; then 
        $exit_code="$1"
    fi 

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then 
        if [[ -n ${script_output-} ]]; then 
            exec 1>&3 2>&4
        fi

        # print basic debugging information 
        printf '====== Abnormal Termination of Script ======\n'
        printf 'Script Path:                %s\n' "$script_path"
        printf 'Script Parameter:           %s\n' "$script_params"
        printf 'Script Exit Code:           %s\n' "$exit_code"

        # print the script if have it 
        if [[ -n ${script_output-} ]]; then 
            printf 'Script Output: \n\n%s' "$(cat "$script_output")"
        else 
            printf 'Script Output:     None (failed before log init)\n'
        fi 
    fi

    # Exit with failure status 
    exit "$exit_code"
}

# DESC: Handler for exiting the scipt 
# ARGS: None 
# OUTS: None 
function script_trap_exit() {
    cd "$cwd"
    # Remove cron mode script log 
    printf "$script_output"
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script excution lock 
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

}

# DESC: Generic Script Initialisation 
# ARGS: $@ (optional) Arguments provided to the script
# OUTS: $cwd: The current working directory when the script was run 
#       $script_path: The full path of the script
#       $script_dir: The full path of the script 
#       $script_name: The filename of the scirpt 
#       $script_params: The original parameters given to the script

function script_init() {
    # script meta variables
    readonly cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    script_name="$(basename "$script_path")"
    readonly script_params="$*"
    script_dir="$(dirname "$script_path")"
    readonly script_dir script_name
} 

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF
Usage:
     -vir|--virtual_env           Virtual Env in Conda: default is dev_env_38
     -p|--port                  Port 
     -b|--background            Run 
     -n|--notebook              Open with jupyter notebook
     -l|--lab                   Open with jupyter lab
     -h|--help                  Displays this help
     -v|--verbose               Displays verbose output
    -nc|--no-colour             Disables colour output
    -cr|--cron                  Run silently unless we encounter an error

     Example: 

EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script 
# OUTS: variables indicating command-line options
function parse_params() {
    local param 
    while [[ $# -gt 0 ]]; do
        case $1 in 
            -vir|--virtual_env)
                shift
                VIRTUAL="$1"
                ;;
            -p|--port)
                shift
                PORT=$1
                ;;
            -b|--background)
                BG=1
                ;;
            -n|--notebook)
                JYP_NM="notebook"
                ;;
            -l|--lab)
                JYP_NM="lab"
                ;;
            -h|--help)
                script_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                ;;
            -cr|--cron)
                cron=true
                ;;
            *)
                die "Invalid parameter was provided $1" 1
                ;;
        esac
        shift
    done 
}

# DESC: Initialise Cron Mode
# ARGS: None 
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then 
        # Redirect all of the output to a temperory file
        script_output="$(mktemp "$script_name".XXXXX)"
        readonly script_output
        exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}

function msg() {
    echo >&2 "${1-}"
}

function die() {
    local msg=$1
    local code=${2-1}
    msg "$msg"
    exit "$code" # default to 1 
}

function sanity_check() {
    if [[ "$USER" != "liangliang" ]] 
    then 
        die "$script_name ERROR: only liangliang could use this script" 1
    fi

    if [[ -z "$PORT" ]] 
    then 
        msg "$script_name port is not provided, default to 8888"
    fi

    if [[ -n "$PORT" ]] 
    then
        if [[ "$PORT" > "9999" ]] 
        then
            die "$script_name port can not be larger than 9999" 1 
        fi
    fi
}

function variable_init() {
    VIRTUAL="dev_env_38"
    JPY_NM="notebook"
}

function start_process() {
    # activate the environment 
    source activate $VIRTUAL

    # open notebook
    if [[ -n "$BG" ]]
    then 
        if [[ -n "$PORT" ]]
        then 
            nohup jupyter "$JPY_NM" --port="$PORT" --ip="*" > /dev/null 2>&1 &
        else
            nohup jupyter "$JPY_NM" --ip="*" > /dev/null 2>&1 &
        fi
    else
        if [[ -n "$PORT" ]]
        then 
            jupyter "$JPY_NM" --port="$PORT" --ip="*"
        else
            jupyter "$JPY_NM" --ip="*"
        fi
    fi
}

# main function 
function main() {
    trap script_trap_err ERR  
    trap script_trap_exit EXIT 
    echo $APP_NAME
    echo 'Script Initialisation Started'
    script_init "$@"
    parse_params "$@"
    variable_init
    #cron_init
    echo 'Script Initialisation Finished'
    sanity_check
    start_process
    echo 'Finished'
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi
