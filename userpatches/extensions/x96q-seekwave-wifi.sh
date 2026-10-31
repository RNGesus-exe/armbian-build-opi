# shellcheck shell=bash
# shellcheck disable=SC2154 # Armbian provides these extension hook globals.
#
# SeekWave SWT6621S SDIO Wi-Fi for the H618 TV box built as BOARD=x96q-v5-1.
# Adapted from https://github.com/luisdosreis/linknlink-isg-box-se-armbian
# (userpatches/extensions/isg-seekwave-driver.sh, commit e89771b), Wi-Fi only:
# Bluetooth support is compiled into the SDIO driver as upstream does, but
# skwbt.ko is not shipped or loaded.
# Driver source:  userpatches/drivers/seekwave-swt6621s (with 6.6 compat fixes)
# Firmware:       userpatches/firmware/seekwave-swt6621s
# Enable with:    ENABLE_EXTENSIONS=x96q-seekwave-wifi

function pre_package_kernel_image__build_x96q_seekwave_wifi() {
	local src_dir="${USERPATCHES_PATH}/drivers/seekwave-swt6621s/src"
	local platform_header_src="${USERPATCHES_PATH}/drivers/seekwave-swt6621s/include/linux/platform_data/skw_platform_data.h"
	local platform_header_dst="${kernel_work_dir}/include/linux/platform_data/skw_platform_data.h"
	local module_dir="${tmp_kernel_install_dirs[INSTALL_MOD_PATH]}/lib/modules/${kernel_version_family}/extra/seekwave"
	local -a make_args=(
		-C "${kernel_work_dir}" M="${src_dir}"
		ARCH="${ARCHITECTURE:-${ARCH}}" CROSS_COMPILE="${KERNEL_COMPILER:-}"
		CONFIG_BT=m CONFIG_BT_RFCOMM=m CONFIG_SKW_BT=m
		CONFIG_SEEKWAVE_BSP_DRIVERS=m CONFIG_SKW_SDIOHAL=m CONFIG_WLAN_VENDOR_SWT6621S=m
	)
	local module

	[[ -f "${src_dir}/Makefile" ]] || exit_with_error "Extension: ${EXTENSION}: missing SWT6621S driver source" "${src_dir}"
	[[ -f "${platform_header_src}" ]] || exit_with_error "Extension: ${EXTENSION}: missing platform header" "${platform_header_src}"

	display_alert "Extension: ${EXTENSION}: staging SeekWave platform header" "$(basename "${platform_header_dst}")" "info"
	mkdir -p "$(dirname "${platform_header_dst}")"
	cp "${platform_header_src}" "${platform_header_dst}"

	display_alert "Extension: ${EXTENSION}: building SWT6621S Wi-Fi driver" "${kernel_version_family}" "info"
	run_host_command_logged make "${make_args[@]}" clean
	run_host_command_logged make "${make_args[@]}" modules

	install -d "${module_dir}"
	for module in seekwaveplatform_lite/skw_sdio_lite.ko swt6621s_wifi/swt6621s_wifi.ko; do
		[[ -f "${src_dir}/${module}" ]] || exit_with_error "Extension: ${EXTENSION}: module was not built" "${module}"
		install -m 0644 "${src_dir}/${module}" "${module_dir}/"
	done
	# modules_install already ran depmod; refresh it so modules-load.d finds the extra modules by name
	run_host_command_logged depmod -b "${tmp_kernel_install_dirs[INSTALL_MOD_PATH]}" "${kernel_version_family}"

	# Leave the source tree clean so build artifacts don't end up in git
	run_host_command_logged make "${make_args[@]}" clean
}

function pre_customize_image__install_x96q_seekwave_wifi() {
	local firmware_src="${USERPATCHES_PATH}/firmware/seekwave-swt6621s"
	local firmware

	[[ -d "${firmware_src}" ]] || exit_with_error "Extension: ${EXTENSION}: missing SeekWave firmware" "${firmware_src}"

	display_alert "Extension: ${EXTENSION}: installing SWT6621S firmware and autoload" "skw_sdio_lite + swt6621s_wifi" "info"
	# The driver requests these by bare name from /lib/firmware
	for firmware in "${firmware_src}"/*; do
		install -m 0644 "${firmware}" "${SDCARD}/lib/firmware/$(basename "${firmware}")"
	done

	install -d -m 0755 "${SDCARD}/etc/modules-load.d"
	cat > "${SDCARD}/etc/modules-load.d/seekwave-wifi.conf" <<- 'EOF'
		skw_sdio_lite
		swt6621s_wifi
	EOF
}
