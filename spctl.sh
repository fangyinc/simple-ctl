#!/bin/bash

# servers to be operated
servers=$1
# read next cmd
# shift

# operate type
opt_type=$2

copy_ssh_key(){
    password=$1
    for host_ip in $(cat ${servers})
    do
        sshpass -p ${password} ssh-copy-id -i ~/.ssh/id_rsa.pub root@${host_ip} -o "StrictHostKeyChecking no"
    done
}

# send file or directory to all servers
scp_files(){
    src=$1
    dst=$2
    for i in $(cat ${servers}); do
        if [ -d ${src} ]; then
            scp -r ${src} root@${i}:$dst &
        else
            scp ${src} root@${i}:$dst &
        fi
    done
    wait
}

# execute commands on all servers
exec_cmd(){
    for i in $(cat ${servers}); do
        cmd="$1 && echo \"[$i] completed -> [$1]---------------------------------------\""
        ssh root@$i "${cmd}" &
    done
    wait
}

run_script(){
    tmp_name="tmp_script_to_run.sh"
    scp_files $1 "/tmp/$tmp_name"
    exec_cmd "chmod +x /tmp/$tmp_name && sh /tmp/$tmp_name"
}
usage(){
    echo "Usage:"
    echo "-cp:      $0 servers.txt -cp src-file dst-file"
    echo "-c:       $0 servers.txt -c [cmd]"
    echo "-s:       $0 servers.txt -s [script.sh]"
    echo "-ssh:     $0 servers.txt -ssh [password]" 
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
esac