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
    set +o pipfail 

    # Validate provided exit code 
    if [[ ${1-} =~ ^[0-9]+$ ]]; then 
        exit_code="$1"
    fi 

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then 
        if [[ -n ${script_output-} ]]; then 
            exec 1>&3 2>&4
        fi

        # print basic debugging information 
        printf '%b\n' "$ta_none"
        printf '====== Abnormal Termination of Script ======\n'
        printf 'Script Path:                %s\n' "$script_path"
        printf 'Script Parameter:           %s\n' "$script_params"
        printf 'Script Exit Code:           %s\n' "$exit_code"

        # print the script if have it 
        if [[ -n ${script_output-} ]]; then 
            printf 'Script Output: \n\n%s' "$(cat "$script_outpur")"
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
    cd "$orig_cwd"
    
    # Remove cron mode script log 
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_out"
    fi

    # Remove script excution lock 
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restiore terminal colour
    printf '%b' '$ta_none'
}

# DESC: Parameter parser
function parse_params() {
    local param 
    while [[ $# -gt 0]]; do
        param="$1"
        shift
        case $param in 
            -h | --help)
                script_usage
                exit 0
                ;;
            -v | --verbose)
                verbose=true
                ;;
            -nc | --no-colour)
                no_colour=true
                ;;
            -cr | --cron)
                cron=true
                ;;
            *)
                script_exit "Invalid parameter was provided $param" 1
                ;;
        esac
    done 
}


# main function 
function main() {
    trap script_trap_err ERR  
    trap script_trap_exit EXIT 


}
