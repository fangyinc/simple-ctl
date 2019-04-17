#!/bin/bash

# servers to be operated
servers=$1
# read next cmd
# shift

# operate type
opt_type=$2

config_file="/etc/spctl/spctl.conf"
# 当前主机用户
opt_user=""
# 待被操作主机的用户
dst_user=""

function get_config() {
    local config_path=$1
    local config_name=$2
    sed -n 's/^[[:space:]]*'$config_name'[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)\([[:space:]]*\)$/\1/p' $config_path
}

function set_config() {
    local config_path=$1
    local config_name=$2
    local config_value=$3
    sed -i 's/^[[:space:]]*'$config_name'[[:space:]]*=.*/'$config_name'='$config_value'/g' $config_path
}

# 获取当前机器的操作用户
opt_user=`get_config ${config_file} user`
# 获取目标主机的用户
dst_user=`get_config ${config_file} dst_user`

if [ ! -n "${dst_user}" ];then
    echo "没有配置默认待操作用户, 使用作目标主机用户: root"
    dst_user="root"
fi
current_user=`whoami`

if [ ! -n "${opt_user}" ];then
    echo "未配置当前默认操作用户, 使用当前用户: ${current_user}"
elif [ "$current_user" != "$opt_user" ];then
    echo "当前用户${current_user}与默认操作用户${opt_user}不匹配, 不能操作，请检查配置"
    exit 1
fi

ssh_keygen_at_dst(){
    password=$1
    for host_ip in $(cat ${servers})
    do
        sshpass -p ${password} ssh ${dst_user}@${host_ip} "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa" &
    done
    wait
}

copy_ssh_key(){
    password=$1
    for host_ip in $(cat ${servers})
    do
        sshpass -p ${password} ssh-copy-id -i ~/.ssh/id_rsa.pub   ${dst_user}@${host_ip} -o "StrictHostKeyChecking no" &
    done
    wait
}

# send file or directory to all servers
scp_files(){
    src=$1
    dst=$2
    for i in $(cat ${servers}); do
        if [ -d ${src} ]; then
            scp -r ${src} ${dst_user}@${i}:$dst &
        else
            scp ${src} ${dst_user}@${i}:$dst &
        fi
    done
    wait
}

# execute commands on all servers
exec_cmd(){
    for i in $(cat ${servers}); do
        cmd="$1 && echo \"[$i] completed -> [$1]---------------------------------------\""
        ssh ${dst_user}@$i "${cmd}" &
    done
    wait
}

run_script(){
    tmp_name="tmp_script_to_run.sh"
    scp_files $1 "/tmp/$tmp_name"
    exec_cmd "chmod +x /tmp/$tmp_name && sh /tmp/$tmp_name"
}
usage(){
    _cmd="spctl"
    echo "Usage:"
    echo "-cp:      ${_cmd} servers.txt -cp src-file dst-file"
    echo "-c:       ${_cmd} servers.txt -c [cmd]"
    echo "-s:       ${_cmd} servers.txt -s [script.sh]"
    echo "-ssh:     ${_cmd} servers.txt -ssh [password]"
    echo "-ssh-gen  ${_cmd} servers.txt -ssh-gen [password]"
}


if [ ! -n "${opt_type}" ];then
    usage
    exit 1
fi
case $opt_type in
    -cp)
        if [[ -n "$3" && -n "$4" ]]; then
            scp_files $3 $4
        else
            usage
            exit 1
        fi
        ;;
    -c)
        if [ ! -n "$3" ]; then
            usage
            exit 1
        else
            # 用引号的目的是把$3中的所有输入当初字符串处理(避免因为空格分隔把命令切分成多个)
            exec_cmd "$3"
        fi
        ;;
    -s)
        if [ ! -n "$3" ]; then
            usage
            exit 1
        else
            run_script "$3"
        fi
        ;;
    -ssh)
        if [ ! -n "$3" ]; then
            echo "please input password"
            usage
            exit 1
        else
            copy_ssh_key "$3"
        fi
        ;;
    -ssh-gen)
        if [ ! -n "$3" ]; then
            echo "please input password"
            usage
            exit 1
        else
            ssh_keygen_at_dst "$3"
        fi
        ;;
    *)
        echo "error input"
        usage
        exit 1
        ;;
esac
