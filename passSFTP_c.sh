#!/bin/bash
#### initilize local variable ####
cmd=`basename $0`
if [ $PGNAME ];then
   pgname=${PGNAME}
else
   exit 1
fi
date="null"
status=
error_code=0
REPORT=NO

#### reference common function utilities ####
source ${UTIL_HOME}/bin/job2report.sh

#### initialize log status ####
if [ $LOG = "YES" ]; then
   exec 1>> "${SHELL_LOG_DIR}/${cmd}`date '+%Y%m%d'`.log"
   exec 2>> "${SHELL_LOG_DIR}/${cmd}`date '+%Y%m%d'`.log"
fi

#### define function utilities ###
log_proc()
   {
   echo "${date:+`date '+%Y%m%d:%H%M%S'`} $*"
   }
log_start()
   {
   log_proc "#############################################################"
   log_proc "######################### start #############################"
   log_proc "#############################################################"
   }
log_end()
   {
   log_proc "#############################################################"
   log_proc "########################## end ##############################"
   log_proc "#############################################################"
   log_proc " "
   }
log_error()
   {
   log_proc [Error] $*
   log_proc "#############################################################"
   log_proc "######################### error #############################"
   log_proc "#############################################################"
   }

#### define process function ####
main()
{
    #1 PROC_ACT
    #2 Vendor Path
    #3 FileName
    #4 Account
    #5 Passwod
    #snd ts ${txtFile}
    if [ ${1} ]; then
       proc_act=${1}
    else
       log_error "param error:proc_act"
       exit 1
    fi
    log_proc proc_act=${proc_act}

    if [ ${2} ]; then
       vendor_path=${2}
    else
       log_error "param error:vendor_path"
       exit 1
    fi
    log_proc vendor_path=${vendor_path}

    if [ ${3} ]; then
       file_name=${3}
    else
       log_error "param error:file_name"
       exit 1
    fi

    log_proc file_name=${file_name}

    if [ ${4} ]; then
	user_acc=${4}
    else 
	log_error "param error:user_acc"
	exit 1
     fi

    log_proc user_acc=${user_acc}

    if [ ${5} ]; then
	user_pwd=${5}
    else 
	log_error "param error:user_pwd"
	exit 1
     fi

    log_proc user_pwd=${user_pwd}

    ### download/upload  file FTP ###
    if [ ${proc_act} = "get" ]; then
       work_dir=${RCV_DIR}
    else
       work_dir=${SND_DIR}
    fi

    hist_dir=${work_dir}/history/PassSFTP
    ##Create Backup Folder
    if [ ! -d ${hist_dir} ]; then
       log_proc "mkdir ${hist_dir}"
       mkdir ${hist_dir}
    fi

    log_proc work_dir=${work_dir}
    log_proc hist_dir=${hist_dir}

    log_proc Get FTP Server Info
    sftpsr_list=${ETC_DIR}/ftpsr.lst
    sftpip=`awk '{print $1}' ${sftpsr_list}`
    sftpputdir=`awk '{print $2}' ${sftpsr_list}`
    sftpgetdir=`awk '{print $3}' ${sftpsr_list}`

    log_proc sftpip=${ftpip}
    log_proc sftpput=${sftpput}
    log_proc sftpget=${sftpget}

    execnm=`echo ${cmd} | cut -d'.' -f1`
    #ftp_cmd_file=${STATUS_LOG_DIR}/${execnm}_ftp${proc_act}_`date '+%Y%m%d%H%M%S'`.txt
    #log_proc "ftp_cmd_file:${ftp_cmd_file}"
    log_proc "cd ${work_dir}"
    cd ${work_dir}

    if [ "${proc_act}" = "get" ]; then
      dir="${sftpgetdir}/$2"
    else 
      dir="${sftpputdir}/$2"
    fi
    

    expect -c "
       spawn sftp ${user_acc}@${sftpip}
       expect \"password:\"
       send \"${user_pwd}\r\"
       expect \"sftp>\"
       send \"cd  ${dir}\r\"
       expect \"sftp>\"
       send \"${proc_act} ${file_name}\r\"
       expect \"sftp>\"
       send \"bye\r\"
       expect \"sftp>\"
       exit 0
    "

    ##Delete FTP File
    if [ "${proc_act}" = "get" ]; then

       ##Check File exist
       log_proc Check File
       file_cnt=0
       for file in find ${work_dir}/${file_name}
       do
          if [ -f ${file} ]; then
             file_cnt=$(($file_cnt+1))
	     expect -c "
	       spawn sftp ${user_acc}@${sftpip}
	       expect \"password:\"
	       send \"${user_pwd}\r\"
	       expect \"sftp>\"
	       send \"cd  ${sftpgetdir}\r\"
	       expect \"sftp>\"
	       send \"rm ${file}\r\"
	       expect \"sftp>\"
	       send \"bye\r\"
	       expect \"sftp>\"
	       exit 0
	       "
	  fi
       done

       log_proc file_cnt=${file_cnt}
       if [ "${file_cnt}" = "0" ]; then
          log_proc "input file does not exist:${srcFile}"
          exit 1
       fi

    else
       ##Snd File Move To History
       for file in find ${work_dir}/${file_name}
       do
          if [ -f ${file} ]; then
             log_proc "move ${file} to ${hist_dir}"
             mv ${file} ${hist_dir}
          fi
       done
    fi

    ##delete file
    log_proc Delete History Log Before 90 Days
    log_proc ${UTIL_HOME}/bin/clear_file.sh d ${LOG_DIR} ${execnm} 90
    ${UTIL_HOME}/bin/clear_file.sh d ${LOG_DIR} ${execnm} 90

    log_proc Delete History File Before 90 Days
    for LST1 in `find ${hist_dir}/* -type f -mtime +90`
    do
        log_proc rm ${LST1}
        rm ${LST1}
    done

}

#### log start ####
log_start

#### report start ####
report_start

#### process ####
main $1 $2 $3 $4 $5

#### log end ####
log_end

#### report end ####
report_end

