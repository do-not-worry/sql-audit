#!/bin/sh
#发布SQL自动审核脚本,避免大量重复劳动

CONFIG_FILE=./audit.conf
COOKIE_FILE=./cookie.txt
LIST_HTML=./list.html
userAgent='Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36'
retryNum=0

#获取我的待审核列表
function getMyList()
{
	#防止多次循环调用产生脏数据
	unset result
	result=()
	listUrl=`cat ${CONFIG_FILE} | grep 'listUrl' | awk -F'listUrl=' '{print($2)}'`
	applyerId=`cat ${CONFIG_FILE} | grep 'applyerId' | awk -F'applyerId=' '{print($2)}'`
	auditor=`cat ${CONFIG_FILE} | grep 'auditor' | awk -F'auditor=' '{print($2)}'`
	
	#applyerId是数组,按每个人循环获取要我审核的SQL
	needLogin=0
	for userId in ${applyerId[@]}
	do
		listParams="db_env_type=prod&state=1&create_erp_uid=${userId}&kw=&page=1&pageSize=50"
		curl -d ${listParams} -A "${userAgent}" -b "${COOKIE_FILE}" "${listUrl}" > ${LIST_HTML}
		if [ `cat ${LIST_HTML} | grep '/index/login.html' | wc -l` -gt 0 ];then
			echo "登录信息已过期,重新登录中..."
			needLogin=1
			break
		else
			rows=`cat ${LIST_HTML} | grep -n "<td align=\"left\">${auditor}</td>" | cut -d':' -f1`  #审核人所在的列数
			for row in ${rows[@]}
			do
				if [ -n ${row} ];then #有值才添加至肯德基豪华午餐
				    let row=row-3 #id所在的行
				    result[${#result[@]}]=`sed -n ${row}p ${LIST_HTML} | tr -cd '[0-9]'`
				fi
			done			
		fi
	done
	
	if [ ${needLogin} -eq 1 ];then
		doLogin
		getMyList
	else
		audit ${result[*]}
	fi
}


#登录
function doLogin()
{
	let retryNum=retryNum+1
	if [ ${retryNum} -gt 3 ];then
		echo "已连续登录3次,自动退出！"
		exit
	fi
	
	loginUrl=`cat ${CONFIG_FILE} | grep 'loginUrl' | awk -F'loginUrl=' '{print($2)}'`
	username=`cat ${CONFIG_FILE} | grep 'username' | awk -F'username=' '{print($2)}'`
	password=`cat ${CONFIG_FILE} | grep 'password' | awk -F'password=' '{print($2)}'`
	postData="e_user=${username}&e_pass=${password}"
	
	curl -d ${postData} -A "${userAgent}" -c "${COOKIE_FILE}" "${loginUrl}"
}


#审核SQL
#$1:审核id数组
function audit()
{
	auditUrl=`cat ${CONFIG_FILE} | grep 'auditUrl' | awk -F'auditUrl=' '{print($2)}'`

	result=$1
    for id in ${result[@]}
    do
        auditParams="check_result=10&check_result_message=ok&id=${id}"
        auditRes=`curl -d ${auditParams} -A "${userAgent}" -b "${COOKIE_FILE}" "${auditUrl}"`
        if [[ ${auditRes} =~ '"error_code":0' ]];then
            echo ${id}"审核成功!"
        else
            echo ${id}${auditRes}
        fi
    done
}

getMyList