
def_env_var() {
    varName=$1
    varValue=$2
    echo "Set $varName to $varValue"
    if $GITHUB_ACTIONS
    then
        echo "$varName=\"$varValue\"" >> $GITHUB_ENV
    else
        eval "export $varName=\"$varValue\""
    fi
}