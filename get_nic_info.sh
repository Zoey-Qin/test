#!/bin/bash

# menu
menu() {
    while true; do
        read -p $'\e[33m请输入选项（1-继续查询，2-退出脚本）: \e[0m' option
        case $option in
            1)
                main
                ;;
            2)
                exit
                ;;
            *)
                echo "无效的选项"
                ;;
        esac
    done
}

# 验证ip
validate_ip() {
    while true; do
        read -p "请输入IP地址: " ip
        if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "无效的IP地址格式，请确认后重新输入"
        else
            if ! ip addr | grep -q "$ip"; then
                echo "未查询到该IP相关信息，请确认是否为本机信息"
            else
                break
            fi
        fi
    done
}

# 获取IP对应的网卡名称
get_interface_name() {
    ip=$1
    interface=$(ip -o addr show | awk -v ip="$ip" '$0 ~ ip {print $2}')
    echo "$interface"
}

# 获取网卡速率
get_interface_speed() {
    interface=$1
    speed=$(ethtool "$interface" | awk '/Speed:/ {print $2}')
    echo "$speed"
}

# 获取子网卡信息
get_sub_interface_info() {
    interface=$1
    if [[ -d "/sys/class/net/$interface/bonding" ]]; then
        sub_interfaces=$(cat "/sys/class/net/$interface/bonding/slaves")
        echo "$sub_interfaces"
    else
        sub_interfaces=$(ls -d "/sys/class/net/$interface/"*bond*/)
        for sub_interface in $sub_interfaces; do
            if [[ -d "$sub_interface/bonding" ]]; then
                sub_interface_name=$(cat "$sub_interface/bonding/slaves")
                echo "$sub_interface_name"
            fi
        done
    fi
}

# 检查是否存在带有"bond"名称的文件夹
check_bond_folder() {
    interface=$1
    shopt -s nullglob
    bond_folders=(/sys/class/net/$interface/*bond*)
    shopt -u nullglob
    if [[ -n "$bond_folders" ]]; then
        return 0
    else
        return 1
    fi
}

# 获取网卡信息
get_interface_info() {
    interface=$1
    if [[ -d "/sys/class/net/$interface" ]]; then
        echo "网卡名称: $interface"
        speed=$(get_interface_speed "$interface")
        echo "网卡速率: $speed"
        if [[ -d "/sys/class/net/$interface/bridge" ]]; then
            echo "该网卡是桥接网卡"
        fi
        if [[ -d "/sys/class/net/$interface/bonding" ]]; then
            echo "网卡类型：bond"
            bond_folder=(/sys/class/net/$interface/bonding)
            layer=$(cat "$bond_folder/xmit_hash_policy")
            mode=$(cat "$bond_folder/mode")
            echo "bond 类型：$layer"
            echo "bond 模式：$mode"
            echo "子网卡信息:"
            sub_interfaces=$(get_sub_interface_info "$interface")
            echo "$sub_interfaces"
            break

        elif check_bond_folder "$interface"; then
            echo "网卡类型：bond"
            bond_folders=(/sys/class/net/$interface/*bond*)
            if [[ ${#bond_folders[@]} -gt 0 ]]; then
                bond_folder=${bond_folders[0]}
                layer=$(cat "$bond_folder/bonding/xmit_hash_policy")
                mode=$(cat "$bond_folder/bonding/mode")
                echo "bond 类型：$layer"
                echo "bond 模式：$mode"
                echo "子网卡信息:"
                sub_interfaces=$(get_sub_interface_info "$interface")
                echo "$sub_interfaces"
            else
                echo "无法获取bond类型和模式"
            fi
        else
            echo "网卡类型：单网卡"
        fi

    else
        echo "找不到网卡: $interface"
    fi
}

# 主函数
main() {

    validate_ip
    interface=$(get_interface_name "$ip")
    # 获取网卡信息
    get_interface_info "$interface"
    # 菜单
    menu
}
main
