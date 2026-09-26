#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

mkdir -p ./package/base-files/files/etc/uci-defaults/

cat << EOF > ./package/base-files/files/etc/uci-defaults/99-custom-config
#!/bin/sh

# ----------------- 1. WiFi 三频 SSID 名称与密码配置 -----------------
uci -q batch <<-UCI_EOF
	# ===== Radio 0 (5G1) =====
	set wireless.radio0.disabled='0'
	set wireless.radio0.country='US'
	set wireless.radio0.channel="149"
	set wireless.radio0.htmode="HE80"
	set wireless.default_radio0.ssid="${WRT_SSID}"
	set wireless.default_radio0.encryption="psk2+ccmp"
	set wireless.default_radio0.key="${WRT_WORD}"

	# ===== Radio 1 (2.4G) =====
	set wireless.radio1.disabled='0'
	set wireless.radio1.country='US'
	set wireless.radio1.channel="1"
	set wireless.radio1.htmode="HE20"
	set wireless.default_radio1.ssid="${WRT_SSID}"
	set wireless.default_radio1.encryption="psk2+ccmp"
	set wireless.default_radio1.key="${WRT_WORD}"

	# ===== Radio 2 (5G2) =====
	set wireless.radio2.disabled='0'
	set wireless.radio2.country='US'
	set wireless.radio2.channel="44"
	set wireless.radio2.htmode="HE160"
	set wireless.default_radio2.ssid="${WRT_SSID}"
	set wireless.default_radio2.encryption="psk2+ccmp"
	set wireless.default_radio2.key="${WRT_WORD}"
UCI_EOF
uci commit wireless
wifi reload

exit 0
EOF

chmod +x ./package/base-files/files/etc/uci-defaults/99-custom-config
/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
