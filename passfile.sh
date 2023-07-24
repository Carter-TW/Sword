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

#LOG=NO
#REPORT=NO

#### reference common function utilities ###
source ${UTIL_HOME}/bin/job2report.sh

#### initialize log ? ####
if [ $LOG = "YES" ]; then
   exec 1>> "${SHELL_LOG_DIR}/${cmd}_`date '+%Y%m%d'`.log"
   exec 2>> "${SHELL_LOG_DIR}/${cmd}_`date '+%Y%m%d'`.log"
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
   }
log_error()
   {
   log_proc [Error] $*
   log_proc "#############################################################"
   log_proc "######################### error #############################"
   log_proc "#############################################################"
   }
log_ari_error()
   {
   log_proc "[ARI Error] $*"
   }

#### define process function ####
tfm_clc_passfile()
  {
    if [ ${1} ]; then
       proc_date=${1}
    else
       proc_date=`date '+%Y%m%d'`
    fi
    log_proc "proc_date = ${proc_date}"

    #Declare variable
    M1_CLC_RCV_PUT=${CCP_HOME}/rcv
    FILENAME=${ETC_DIR}/passfile.lst
    setcnt=`cat ${FILENAME} | wc -l`
    log_proc "setcnt=${setcnt}"

    apsr_list=${ETC_DIR}/apsr.lst
    log_proc "apsr_lst=${apsr_list}"

    ftpip=`awk '{print $1}' ${apsr_list}`
    ftpusr=`awk '{print $2}' ${apsr_list}`
    ftppwd=`awk '{print $3}' ${apsr_list}`
    ftpputdir=`awk '{print $4}' ${apsr_list}`
    ftpgetdir=`awk '{print $5}' ${apsr_list}`

    log_proc ftpip=${ftpip}
    log_proc ftpusr=${ftpusr}
    log_proc ftppwd=${ftppwd}
    log_proc ftpputdir=${ftpputdir}
    log_proc ftpgetdir=${ftpgetdir}

    now=`date '+%Y%m%d%H%M%S'`
    log_proc "----process passfile_get-----"
    passfile_get
    log_proc "----process passfile_put-----"
    passfile_put
    log_proc "----process passfile_chk_get-----"
    passfile_chk_get

    ### Delete Before 90 day data for LOG
    log_proc "------------------------------------------------------------------                                                                                         -----"
    log_proc "Strar Delete Before 90 day data for log"
    log_proc ${UTIL_HOME}/bin/clear_file.sh d ${LOG_DIR} passfile 90
    ${UTIL_HOME}/bin/clear_file.sh d ${LOG_DIR} passfile 90
    log_proc "END Delete Before 90 day data for log"

    log_proc "Strar Delete Before 90 day data for RCV History"
    log_proc ${UTIL_HOME}/bin/clear_file.sh d ${RCV_DIR}/history/passfile .ZIP 9                                                                                         0
    ${UTIL_HOME}/bin/clear_file.sh d ${RCV_DIR}/history/passfile .ZIP 90
    log_proc "END Delete Before 90 day data for RCV History"

    log_proc "Strar Delete Before 90 day data for SND History"
    log_proc ${UTIL_HOME}/bin/clear_file.sh d ${SND_DIR}/history/passfile .ZIP 9                                                                                         0
    ${UTIL_HOME}/bin/clear_file.sh d ${SND_DIR}/history/passfile .ZIP 90
    log_proc "END Delete Before 90 day data for SND History"
    log_proc "------------------------------------------------------------------                                                                                         -----"

    log_proc job end!
  }

passfile_get()
{
  #ftp clc > ap
  mvgetfile_lst=${STATUS_LOG_DIR}/passfile_mvgetfile_${now}.lst
  ftp_put_file=${STATUS_LOG_DIR}/passfile_ftpput.txt
  cd ${RCV_DIR}
  echo "user ${ftpusr} ${ftppwd}" > ${ftp_put_file}
  echo "bin" >> ${ftp_put_file}
  echo "passive" >> ${ftp_put_file}
  echo "prompt" >> ${ftp_put_file}
  echo "cd ${ftpgetdir}" >> ${ftp_put_file}

  for (( x=1; x<=${setcnt}; x=x+1 ))
  do
     log_proc "line=sed -n "${x}p" ${FILENAME}"
     line=`sed -n "${x}p" ${FILENAME}`
     log_proc "LINE = ${line}"


     vend_path=`echo ${line}|awk '{print $1}'`
     proc_act=`echo ${line}|awk '{print $2}'`
     file_name=`echo ${line}|awk '{print $3}' | sed "s/YYYYMMDD/${proc_date}/g"`
     proc_ap=`echo ${line}|awk '{print $4}'`

     user_acc=`echo ${line}|awk '{print $6}'`
     user_pwd=`echo ${line}|awk '{print $7}'`
     cal_tran=`echo ${line}|awk '{print $8}'` # use upload method  user FTP or SFTP
     
     
     
     log_proc "vend_path = $vend_path"
     log_proc "user_acc = $user_acc"
     log_proc "proc_act = $proc_act"
     log_proc "file_name = $file_name"
     log_proc "proc_ap = $proc_ap"
     if [ "${proc_act}" = "mget" ] || [ "${proc_act}" = "get" ]; then
        #fileserver > ccp
        log_proc "rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh ${cal_tran} ${proc_act} ${vend_path} ${file_name} ${user_acc} ${user_pwd}"
        rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh ${cal_tran} ${proc_act} ${vend_path} ${file_name} ${user_acc} ${user_pwd}
        
        if [ $? -ne 0 ]; then
           log_error "fileserver > ccp errror"
           report_error
           exit 1
        fi

        #ccp > clc(local)
        log_proc "rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh file2clc ${M1_CLC_RCV_PUT} ${file_name}"
        rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh file2clc ${M1_CLC_RCV_PUT}                                                                                          ${file_name}
        if [ $? -ne 0 ]; then
           log_error "ccp > clc errror"
           report_error
           exit 1
        fi

        if [ $proc_ap = "Y" ]; then
           echo "mput ${file_name}" >> ${ftp_put_file}
           find ${RCV_DIR}/${file_name} >> ${mvgetfile_lst}
        fi
     fi
  done
  echo "bye" >> ${ftp_put_file}

  log_proc `cat ${ftp_put_file}`
  log_proc "cat ${ftp_put_file} | ftp -n $ftpip"
  cat ${ftp_put_file} | ftp -n $ftpip
  if [ $? -ne 0 ]; then
     log_error "ftp clc > ap errror"
     report_error
     exit 1
  fi

  hist_dir=${RCV_DIR}/history/passfile
  #Create Backup Folder
  if [ ! -d ${hist_dir} ]; then
     log_proc "mkdir ${hist_dir}"
     mkdir ${hist_dir}
  fi

  #move get file to history
  if [ -f ${mvgetfile_lst} ] && [ -s ${mvgetfile_lst} ]; then
     cat ${mvgetfile_lst} | while read line ;
     do
        if [ -f ${line} ]; then
           log_proc "move ${line} to ${hist_dir}"
           mv ${line} ${hist_dir}
        fi
     done
  fi
}

passfile_put()
{
  #read passfile Set with ftp clc < ap
  mvputfile_lst=${STATUS_LOG_DIR}/passfile_mvputfile_${now}.lst

  get_apfile="N"
  cat ${FILENAME} | while read line;
  do
     proc_act=$(echo "$line" | cut -d " " -f 2)
     proc_ap=$(echo "$line" | cut -d " " -f 4)
     if [ "${proc_act}" = "mput" ] || [ "${proc_act}" = "put" ]; then
        if [ "${proc_ap}" = "Y" ]; then
           get_apfile="Y"
           break
        fi
     fi
  done
  log_proc get_apfile=${get_apfile}

  if [ "${get_apfile}" = "Y" ]; then
     ap_get_file=${STATUS_LOG_DIR}/passfile_apget.txt
     ap_del_file=${STATUS_LOG_DIR}/passfile_apdel.txt

     #get file from ap server
     cd ${SND_DIR}
     echo "user ${ftpusr} ${ftppwd}" > ${ap_get_file}
     echo "bin" >> ${ap_get_file}
     echo "passive" >> ${ap_get_file}
     echo "prompt" >> ${ap_get_file}
     echo "cd ${ftpputdir}" >> ${ap_get_file}
     cat ${FILENAME} | while read line;
     do
        proc_act=$(echo "$line" | cut -d " " -f 2)
        file_name=$(echo "$line" | cut -d " " -f 3 | sed "s/YYYYMMDD/${proc_date}/g")
        proc_ap=$(echo "$line" | cut -d " " -f 4)

        if [ "${proc_act}" = "mput" ] || [ "${proc_act}" = "put" ]; then
           if [ "${proc_ap}" = "Y" ]; then
              echo "mget ${file_name}" >> ${ap_get_file}
           fi
        fi
     done
     echo "bye" >> ${ap_get_file}

     log_proc `cat ${ap_get_file}`
     log_proc "cat ${ap_get_file} | ftp -n $ftpip"
     cat ${ap_get_file} | ftp -n $ftpip
     if [ $? -ne 0 ]; then
        log_error "ftp clc < ap errror"
        report_error
        exit 1
     fi

     #delete file from ap server
     echo "user ${ftpusr} ${ftppwd}" > ${ap_del_file}
     echo "bin" >> ${ap_del_file}
     echo "passive" >> ${ap_del_file}
     echo "prompt" >> ${ap_del_file}
     echo "cd ${ftpputdir}" >> ${ap_del_file}
     cat ${FILENAME} | while read line;
     do
        proc_act=$(echo "$line" | cut -d " " -f 2)
        file_name=$(echo "$line" | cut -d " " -f 3 | sed "s/YYYYMMDD/${proc_date}/g")
        proc_ap=$(echo "$line" | cut -d " " -f 4)

        if [ "${proc_act}" = "mput" ] || [ "${proc_act}" = "put" ]; then
           if [ "${proc_ap}" = "Y" ]; then
              echo "mdelete ${file_name}" >> ${ap_del_file}
           fi
        fi
     done
     echo "bye" >> ${ap_del_file}

     log_proc `cat ${ap_del_file}`
     log_proc "cat ${ap_del_file} | ftp -n $ftpip"
     cat ${ap_del_file} | ftp -n $ftpip
     if [ $? -ne 0 ]; then
        log_error "ftp delete ap file errror"
        report_error
        exit 1
     fi
  fi

  #ftp clc > ccp@M1 and ccp@M1 > ftpserver
  for (( x=1; x<=${setcnt}; x=x+1 ))
  do
     log_proc "line=sed -n "${x}p" ${FILENAME}"
     line=`sed -n "${x}p" ${FILENAME}`
     log_proc "LINE = ${line}"

     vend_path=$(echo "$line" | cut -d " " -f 1)
     proc_act=$(echo "$line" | cut -d " " -f 2)
     file_name=$(echo "$line" | awk -F' ' '{print $3}' | sed "s/YYYYMMDD/${proc_date}/g")
     proc_ap=$(echo "$line" | cut -d " " -f 4)
     user_acc=$(echo "$line" | cut -d " " -f 6)
     user_pwd=$(echo "$line" | cut -d " " -f 7)
     cal_tran=$(echo "$line" | cut -d " " -f 8) #use upload method  user FTP or SFTP
     

     log_proc "vend_path = $vend_path"
     log_proc "proc_act = $proc_act"
     log_proc "file_name = $file_name"
     log_proc "proc_ap = $proc_ap"
     log_proc "user_acc = $user_acc"
     log_proc "ususer_pwder = $user_pwd"
     log_proc "cal_tran = $cal_tran"
     
     

     if [ "${proc_act}" = "mput" ] || [ "${proc_act}" = "put" ]; then
        #ccp@M1 < clc(local)
        log_proc "rcp ${SND_DIR}/${file_name} ${M1_CLC_SND}"
        rcp ${SND_DIR}/${file_name} ${M1_CLC_SND}
        #if [ $? -ne 0 ]; then
        #   log_proc "ccp < clc errror"
        #   report_error "ccp < clc errror"
        #   exit 1
        #fi

        #fileserver < ccp
        log_proc "rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh ${cal_tran} ${proc_act} ${vend_path} ${file_name} ${user_acc} ${user_pwd} "
        rsh ${M1_HOST} -l ccp ${CCP_HOME}/bin/run.sh  ${cal_tran} ${proc_act} ${vend_path} ${file_name} ${user_acc} ${user_pwd}
        if [ $? -ne 0 ]; then
           log_error "fileserver < ccp errror"
           report_error
           exit 1
        fi

        find ${SND_DIR}/${file_name} >> ${mvputfile_lst}
     fi
  done

  hist_dir=${SND_DIR}/history/passfile
  #Create Backup Folder
  if [ ! -d ${hist_dir} ]; then
     log_proc "mkdir ${hist_dir}"
     mkdir ${hist_dir}
  fi

  #move get file to history
  if [ -s ${mvputfile_lst} ]; then
     cat ${mvputfile_lst} | while read line ;
     do
        if [ -f ${line} ]; then
           log_proc "move ${line} to ${hist_dir}"
           mv ${line} ${hist_dir}
        fi
     done
  fi
}

passfile_chk_get()
{
  hist_dir=${RCV_DIR}/history/passfile
  errgetfile_lst=${STATUS_LOG_DIR}/passfile_errgetfile_${now}.lst

  for (( x=1; x<=${setcnt}; x=x+1 ))
  do
     line=`sed -n "${x}p" ${FILENAME}`
     log_proc "LINE = ${line}"

     proc_act=`echo ${line}|awk '{print $2}'`
     file_name=`echo ${line}|awk '{print $3}' | sed "s/YYYYMMDD/${proc_date}/g"`
     proc_chkget=`echo ${line}|awk '{print $5}'`

     if [ "${proc_act}" = "mget" ] || [ "${proc_act}" = "get" ]; then
       if [ "${proc_chkget}" = "Y" ]; then
         chkfile_cnt=N
         for chkfile_nm in `find ${hist_dir}/${file_name}`
         do
            chkfile_cnt=Y
         done
         if [ "${chkfile_cnt}" = "N" ]; then
            log_proc "file not exists: ${hist_dir}/${file_name}"
            echo "${hist_dir}/${file_name}" >> ${errgetfile_lst}
         fi
       fi
     fi
  done

  if [ -f ${errgetfile_lst} ] && [ -s ${errgetfile_lst} ]; then
     log_error "get ftp file not exists, pls chk ${errgetfile_lst}"
     report_error
     exit 1
  fi

}

#### log start ####
log_start

#### report start ####
report_start

#### process ####
tfm_clc_passfile $1

#### log end ####
log_end

#### report end ####
report_end

