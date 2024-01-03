# https://plzm.blog/202203-env-vars
setEnvVar() {
    varName=$1
    varValue=$2
    echo "Set $varName to $varValue"
    if [ ! -z $GITHUB_ACTIONS ] # this checks if the variable is not empty
    then
        cmd=$(echo -e "echo \x22""$varName""=""$varValue""\x22 \x3E\x3E \x24GITHUB_ENV")
        eval $cmd
    fi
    cmd="export ""$varName""=\"""$varValue""\""
    eval $cmd
} # omg I will never touch bash again