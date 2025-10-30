# easyNOFX

*源项目地址：https://github.com/tinkle-community/nofx*

ASTER 用户注意:
目前只支持USDT不支持USDF，
持仓模式改成必须要单项持仓

一键配置【NOFX】AI交易系统
本程序仅支持 Ubuntu24.04系统

```
wget https://raw.githubusercontent.com/ShenXuGongZi/easyNOFX/refs/heads/main/install_nofx_ubuntu.sh  && chmod +x install_nofx_ubuntu.sh && bash install_nofx_ubuntu.sh `
```

**管理脚本**

```
nofx
```

功能包括：

* 查看服务状态
* 启动/停止/重启服务
* 查看实时日志
* 编辑配置文件
* 备份配置
* 资源监控
* 完全卸载

**一键更新脚本**

* 可一键同步nofx源码更新

```
wget https://raw.githubusercontent.com/ShenXuGongZi/easyNOFX/refs/heads/main/force_update_nofx.sh && chmod +x force_update_nofx.sh  && bash force_update_nofx.sh
```

`找到这一行并修改为你的域名 YOUR\_DOMAIN="hype.teidihen.com"  # 改成你的域名`
