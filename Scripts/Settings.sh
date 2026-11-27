#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

#修改默认WIFI账号密码
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
ROUTER_TOOL="./package/emortal/luci-app-router-tool/root/etc/config/router-tool"
for file in "$ROUTER_TOOL" "$WIFI_UC"; do
	[ -f "$file" ] && sed -i "s/ssid '.*'/ssid '$WRT_SSID'/g; s/key '.*'/key '$WRT_WORD'/g" "$file"
done


CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME=y" >> ./.config
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

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi


#调整京东云RE-CS-02内核大小为12M
IPQ60XX_MK="./target/linux/qualcommax/image/ipq60xx.mk"
if [ -f "$IPQ60XX_MK" ]; then
	sed -i '/define Device\/jdcloud_re-cs-02/,/endef/s/KERNEL_SIZE := .*/KERNEL_SIZE := 12288k/' "$IPQ60XX_MK"
	echo "jdcloud_re-cs-02 KERNEL_SIZE set to 12288k!"
fi


# 自定义三频 Wi-Fi 默认地区、频宽与信道
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-custom-wifi-channel
#!/bin/sh

(
	# 等待系统完成无线驱动加载与 /etc/config/wireless 初始化
	sleep 5
	i=0
	while [ "$i" -lt 30 ]; do
		if uci -q get wireless.radio0 >/dev/null && \
		   uci -q get wireless.radio1 >/dev/null && \
		   uci -q get wireless.radio2 >/dev/null; then
			break
		fi
		[ "$i" -eq 5 ] && [ ! -s /etc/config/wireless ] && /sbin/wifi config
		i=$((i + 1))
		sleep 2
	done

	# 2.4G (radio1): 信道 1, 频宽 20MHz
	uci set wireless.radio1.country='US'
	uci set wireless.radio1.channel='1'
	uci set wireless.radio1.htmode='HE20'

	# 5.8G (radio0): 信道 149, 频宽 80MHz
	uci set wireless.radio0.country='US'
	uci set wireless.radio0.channel='149'
	uci set wireless.radio0.htmode='HE80'

	# 5.2G (radio2): 信道 36, 频宽 160MHz
	uci set wireless.radio2.country='US'
	uci set wireless.radio2.channel='36'
	uci set wireless.radio2.htmode='HE160'

	uci commit wireless
	/sbin/wifi reload
) </dev/null >/dev/null 2>&1 &

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-wifi-channel
