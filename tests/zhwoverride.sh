#!/bin/sh
#
# Install zhw with a few overrides and then ensure the zFS files are laid down
#
. zbrewfuncs
mydir=$(callerdir ${0})
#set -x
sw='zhw110'
zosname=$(echo ${sw} | tr '[:lower:]' '[:upper:]');
ussname=$(echo ${sw} | tr '[:upper:]' '[:lower:]');
prefix=`echo "${ussname}" | awk '{ print substr($1, 0, 3) }'`

${mydir}/../../zbrew/build.sh # required if first ever run
zbrewpropse zbrew config ${mydir}/../../zbrew/properties/zbrewprops.json
zbrewpropse zhw110 install ${mydir}/../zhw110/zhw110install.json
smpelibs="${mydir}/../../zbrew-${prefix}/${ussname}/${ussname}bom.json"

libs=`readbom ${zosname} <${smpelibs}`
# Obtain list of ZFS and allocate/mount
ds=`echo "${libs}" | awk -v pfx="${ZBREW_HLQ}${zosname}." '($2 == "ZFS") {print pfx""$1","}' | tr -d "\n"`
zfscnt=`echo "${ds}" | awk -F, '{}END {print NF}'`
while [ $zfscnt -ge 1 ]; 
do
        zfsds=`echo "${ds}" | awk -F, -v zfsv=$zfscnt '{print $zfsv}'`
	if [ "$zfsds" != "" ]; then 
        	unmount -f ${zfsds} 2>/dev/null
	fi
	zfscnt=`expr $zfscnt - 1`
done

drm -f "${ZBREW_HLQ}zhw*.*"

zosinfo=`uname -rsvI`
version=`echo ${zosinfo} | awk '{ print $3; }'`
release=`echo ${zosinfo} | awk '{ print $2; }'`

case ${release} in
	'03.00' ) 
		export CEE230_CSI='MVS.GLOBAL.CSI'
		;;
	'04.00' )
		export CEE240_CSI='MVS.GLOBAL.CSI'
		;;
esac

zbrew install zhw110
rc=$?
if [ $rc != 0 ]; then
	echo "zbrew install failed with rc:$rc" >&2
	exit 3
fi


zbrew -c install zhw110
rc=$?
if [ $rc != 0 ]; then
        echo "zbrew install failed with rc:$rc" >&2
        exit 5
fi

zbrew smpreceiveptf zhw110 ${ZBREW_HLQ}ZHWZ110.MCSPTF2  
rc=$?
if [ $rc != 0 ]; then
        echo "zbrew receive ptf from z/os file failed with rc:$rc" >&2
        exit 4
fi

zbrew update zhw110
rc=$?
if [ $rc != 0 ]; then
        echo "zbrew update of zhw110 failed with rc:$rc" >&2
        exit 4
fi


zbrew configure zhw110
rc=$?
if [ $rc != 0 ]; then
        echo "zbrew configure failed with rc:$rc" >&2
        exit 4
fi


zbrew uninstall zhw110
rc=$?
if [ $rc != 0 ]; then
        echo "zbrew uninstall failed with rc:$rc" >&2
        exit 6
fi


#
# 
#
if [ "${LEAVES}" != "hw sepzfs" ]; then
	zbrewtest "zbrew configure of zhw110 has wrong value for LEAVES" "hw" "${LEAVES}"
	exit 5
fi

leafdir="${ZFSROOT}${ZFSDIR}"
if ! [ -d "${leafdir}" ]; then
	zbrewtest "leaf directory not created" "${leafdir}" "${leafdir}"
	exit 6
fi

exit 0
