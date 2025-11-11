# easyNOFX(停止更新)

**源项目地址**：https://github.com/tinkle-community/nofx

---

声明：我的一键脚本没任何问题，完全是拉取的官方代码（在代码中完全可以体现），都是在您本地配置。欢迎各位大神或者使用AI审计代码。我最多就是加了个返佣而已。

此项目不会再更新（但是也不会有任何改动，自证清白，方便各位大神审计），建议直接去官方教程[https://github.com/NoFxAiOS/nofx/blob/dev/docs/i18n/zh-CN/README.md](https://github.com/NoFxAiOS/nofx/blob/dev/docs/i18n/zh-CN/README.md)

Claude AI 升级结果 [https://claude.ai/share/f61c8a59-1856-4689-8ed5-17b5749ac5ef](https://claude.ai/share/f61c8a59-1856-4689-8ed5-17b5749ac5ef)

---

安全提醒：
大家在部署前一定要设置好以下安全配置：

1. 配置安全组最小化开放端口，开放 3000 端口供外部访问
2. 修改管理员密码
   在 .env 文件中修改默认密码：NOFX_ADMIN_PASSWORD=your_strong_password_he
   re请使用强密码（12 位以上，包含大小写字母、数字与符号）。
3. 修改 JWT
   秘钥在 config.json 中替换默认
   密钥：“jwt_secret”: “your_random_secret_stri
   ng”可通过命令 openssl rand -hex 32 生成安全密钥。
4. 普通用户 2FA
   双重验证普通用户开启双因素认证（2FA），并使用 Google Authenticator 或 Authy 绑
   定验证。
5. 绑定币安api key和secret一定设置好白名单，千万不要给api开提币权限，只开读取和交易，保证资金安全
6. ASTER 用户注意:目前只支持USDT不支持USDT,持仓模式改成必须要单项持仓.

---

**VPS推荐：**
DMIT（支持USDT支付） [点我注册](https://www.dmit.io/aff.php?aff=14244)  //选香港服务器即可

Linode（注册送100美元）[点我注册领取](https://www.linode.com/lp/refer/?r=1e3ab5787e6535408abb5b4a02e6e96801cf325b)  //需要有信用卡 选印尼或者日本服务器

---

**交易所注册链接：**
hyperliquid(免KYC)：[点我注册](https://app.hyperliquid.xyz/join/HANGZAI)

ASTER<推荐>(免KYC)： [点我注册](https://www.asterdex.com/zh-CN/referral/961369)

币安注册链接：[点我注册](https://www.binance.com/referral/earn-together/refer2earn-usdc/claim?hl=zh-CN&ref=GRO_28502_YXCTX&utm_source=default)

---

**一键配置【NOFX】AI交易系统**

*本程序仅支持 Ubuntu24.04系统*

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
