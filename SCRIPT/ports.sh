#!/bin/bash
SCPfrm="/etc/ger-frm" && [[ ! -d ${SCPfrm} ]] && exit
SCPinst="/etc/ger-inst" && [[ ! -d ${SCPinst} ]] && exit
# FUN TRANS
fun_trans () { 
local texto
local retorno
declare -A texto
SCPidioma="${SCPdir}/idioma"
[[ ! -e ${SCPidioma} ]] && touch ${SCPidioma}
local LINGUAGE=$(cat ${SCPidioma})
[[ -z $LINGUAGE ]] && LINGUAGE=es
[[ $LINGUAGE = "es" ]] && echo "$@" && return
[[ ! -e /usr/bin/trans ]] && wget -O /usr/bin/trans https://www.dropbox.com/s/l6iqf5xjtjmpdx5/trans?dl=0 &> /dev/null
[[ ! -e /etc/texto-adm ]] && touch /etc/texto-adm
source /etc/texto-adm
if [[ -z "$(echo ${texto[$@]})" ]]; then
#ENGINES=(aspell google deepl bing spell hunspell apertium yandex)
#NUM="$(($RANDOM%${#ENGINES[@]}))"
retorno="$(source trans -e bing -b es:${LINGUAGE} "$@"|sed -e 's/[^a-z0-9 -]//ig' 2>/dev/null)"
echo "texto[$@]='$retorno'"  >> /etc/texto-adm
echo "$retorno"
else
echo "${texto[$@]}"
fi
}
port () {
local portas
local portas_var=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN")
i=0
while read port; do
var1=$(echo $port | awk '{print $1}') && var2=$(echo $port | awk '{print $9}' | awk -F ":" '{print $2}')
[[ "$(echo -e ${portas}|grep -w "$var1 $var2")" ]] || {
    portas+="$var1 $var2 $portas"
    echo "$var1 $var2"
    let i++
    }
done <<< "$portas_var"
}
verify_port () {
local SERVICE="$1"
local PORTENTRY="$2"
[[ ! $(echo -e $(port|grep -v ${SERVICE})|grep -w "$PORTENTRY") ]] && return 0 || return 1
}
edit_squid () {
msg -azu "$(fun_trans "REDEFINIR PUERTOS SQUID")"
msg -bar
if [[ -e /etc/squid/squid.conf ]]; then
local CONF="/etc/squid/squid.conf"
elif [[ -e /etc/squid3/squid.conf ]]; then
local CONF="/etc/squid3/squid.conf"
fi
NEWCONF="$(cat ${CONF}|grep -v "http_port")"
msg -ne "$(fun_trans "Nuevos Puertos"): 》"
read -p "" newports
for PTS in `echo ${newports}`; do
verify_port squid "${PTS}" && echo -e "\033[1;33mPort $PTS \033[1;32mOK" || {
echo -e "\033[1;33mPort $PTS \033[1;31mFALLO"
return 1
}
done
rm ${CONF}
while read varline; do
echo -e "${varline}" >> ${CONF}
 if [[ "${varline}" = "#portas" ]]; then
  for NPT in $(echo ${newports}); do
  echo -e "http_port ${NPT}" >> ${CONF}
  done
 fi
done <<< "${NEWCONF}"
msg -azu "$(fun_trans "ESPERE")"
service squid restart &>/dev/null
service squid3 restart &>/dev/null
sleep 1s
msg -bar
msg -azu "$(fun_trans "PUERTOS REDEFINIDOS")"
msg -bar
}
edit_apache () {
msg -azu "$(fun_trans "REDEFINIR PUERTOS APACHE")"
msg -bar
local CONF="/etc/apache2/ports.conf"
local NEWCONF="$(cat ${CONF})"
msg -ne "$(fun_trans "Nuevos Puertos"): 》"
read -p "" newports
for PTS in `echo ${newports}`; do
verify_port apache "${PTS}" && echo -e "\033[1;33mPort $PTS \033[1;32mOK" || {
echo -e "\033[1;33mPort $PTS \033[1;31mFALLO"
return 1
}
done
rm ${CONF}
while read varline; do
if [[ $(echo ${varline}|grep -w "Listen") ]]; then
 if [[ -z ${END} ]]; then
 echo -e "Listen ${newports}" >> ${CONF}
 END="True"
 else
 echo -e "${varline}" >> ${CONF}
 fi
else
echo -e "${varline}" >> ${CONF}
fi
done <<< "${NEWCONF}"
msg -azu "$(fun_trans "ESPERE")"
service apache2 restart &>/dev/null
sleep 1s
msg -bar
msg -azu "$(fun_trans "PUERTOS REDEFINIDOS")"
msg -bar
}
edit_openvpn () {
msg -azu "$(fun_trans "REDEFINIR PUERTOS OPENVPN")"
msg -bar
local CONF="/etc/openvpn/server.conf"
local CONF2="/etc/openvpn/client-common.txt"
local NEWCONF="$(cat ${CONF}|grep -v [Pp]ort)"
local NEWCONF2="$(cat ${CONF2})"
msg -ne "$(fun_trans "Nuevos Puertos"): 》"
read -p "" newports
for PTS in `echo ${newports}`; do
verify_port openvpn "${PTS}" && echo -e "\033[1;33mPort $PTS \033[1;32mOK" || {
echo -e "\033[1;33mPort $PTS \033[1;31mFALLO"
return 1
}
done
rm ${CONF}
while read varline; do
echo -e "${varline}" >> ${CONF}
if [[ ${varline} = "proto tcp" ]]; then
echo -e "port ${newports}" >> ${CONF}
fi
done <<< "${NEWCONF}"
rm ${CONF2}
while read varline; do
if [[ $(echo ${varline}|grep -v "remote-random"|grep "remote") ]]; then
echo -e "$(echo ${varline}|cut -d' ' -f1,2) ${newports} $(echo ${varline}|cut -d' ' -f4)" >> ${CONF2}
else
echo -e "${varline}" >> ${CONF2}
fi
done <<< "${NEWCONF2}"
msg -azu "$(fun_trans "ESPERE")"
service openvpn restart &>/dev/null
/etc/init.d/openvpn restart &>/dev/null
sleep 1s
msg -bar
msg -azu "$(fun_trans "PUERTOS REDEFINIDOS")"
msg -bar
}
edit_dropbear () {
msg -azu "$(fun_trans "REDEFINIR PORTAS DROPBEAR")"
msg -bar
local CONF="/etc/default/dropbear"
local NEWCONF="$(cat ${CONF}|grep -v "DROPBEAR_EXTRA_ARGS")"
msg -ne "$(fun_trans "Nuevos Puertos"): 》"
read -p "" newports
for PTS in `echo ${newports}`; do
verify_port dropbear "${PTS}" && echo -e "\033[1;33mPort $PTS \033[1;32mOK" || {
echo -e "\033[1;33mPort $PTS \033[1;31mFALLO"
return 1
}
done
rm ${CONF}
while read varline; do
echo -e "${varline}" >> ${CONF}
 if [[ ${varline} = "NO_START=0" ]]; then
 echo -e 'DROPBEAR_EXTRA_ARGS="VAR"' >> ${CONF}
 for NPT in $(echo ${newports}); do
 sed -i "s/VAR/-p ${NPT} VAR/g" ${CONF}
 done
 sed -i "s/VAR//g" ${CONF}
 fi
done <<< "${NEWCONF}"
msg -azu "$(fun_trans "ESPERE")"
service dropbear restart &>/dev/null
sleep 1s
msg -bar
msg -azu "$(fun_trans "PUERTOS REDEFINIDOS")"
msg -bar
}
edit_openssh () {
msg -azu "$(fun_trans "REDEFINIR PUERTOS OPENSSH")"
msg -bar
local CONF="/etc/ssh/sshd_config"
local NEWCONF="$(cat ${CONF}|grep -v [Pp]ort)"
msg -ne "$(fun_trans "Nuevos Puertos"): 》"
read -p "" newports
for PTS in `echo ${newports}`; do
verify_port sshd "${PTS}" && echo -e "\033[1;33mPort $PTS \033[1;32mOK" || {
echo -e "\033[1;33mPort $PTS \033[1;31mFALLO"
return 1
}
done
rm ${CONF}
for NPT in $(echo ${newports}); do
echo -e "Port ${NPT}" >> ${CONF}
done
while read varline; do
echo -e "${varline}" >> ${CONF}
done <<< "${NEWCONF}"
msg -azu "$(fun_trans "ESPERE")"
service ssh restart &>/dev/null
service sshd restart &>/dev/null
sleep 1s
msg -bar
msg -azu "$(fun_trans "PUERTOS REDEFINIDOS")"
msg -bar
}
main_fun () {
unset newports
i=0
while read line; do
let i++
          case $line in
          squid|squid3)squid=$i;; 
          apache|apache2)apache=$i;; 
          openvpn)openvpn=$i;; 
          dropbear)dropbear=$i;; 
          sshd)ssh=$i;; 
          esac
done <<< "$(port|cut -d' ' -f1|sort -u)"
for((a=1; a<=$i; a++)); do
[[ $squid = $a ]] && echo -ne "\033[1;32m [$squid] > " && msg -azu "$(fun_trans "REDEFINIR PUERTOS SQUID")"
[[ $apache = $a ]] && echo -ne "\033[1;32m [$apache] > " && msg -azu "$(fun_trans "REDEFINIR PUERTOS APACHE")"
[[ $openvpn = $a ]] && echo -ne "\033[1;32m [$openvpn] > " && msg -azu "$(fun_trans "REDEFINIR PUERTOS OPENVPN")"
[[ $dropbear = $a ]] && echo -ne "\033[1;32m [$dropbear] > " && msg -azu "$(fun_trans "REDEFINIR PUERTOS DROPBEAR")"
[[ $ssh = $a ]] && echo -ne "\033[1;32m [$ssh] > " && msg -azu "$(fun_trans "REDEFINIR PUERTOS SSH")"
done
echo -ne "\033[1;32m [0] > " && msg -azu "$(fun_trans "REGRESAR")"
msg -bar
while true; do
echo -ne "\033[1;37m$(fun_trans "Selecione"): 》" && read selection
tput cuu1 && tput dl1
[[ ! -z $squid ]] && [[ $squid = $selection ]] && edit_squid && break
[[ ! -z $apache ]] && [[ $apache = $selection ]] && edit_apache && break
[[ ! -z $openvpn ]] && [[ $openvpn = $selection ]] && edit_openvpn && break
[[ ! -z $dropbear ]] && [[ $dropbear = $selection ]] && edit_dropbear && break
[[ ! -z $ssh ]] && [[ $ssh = $selection ]] && edit_openssh && break
[[ "0" = $selection ]] && break
done
#exit 0
}
main_fun
