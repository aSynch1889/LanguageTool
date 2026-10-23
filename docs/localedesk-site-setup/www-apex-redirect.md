# www → apex 301（Cloudflare Redirect Rule）

LocaleDesk 规范域名：`https://localedesk.cc`  
`www.localedesk.cc` 应 **301** 到 apex，避免重复收录。

## 在 Dashboard 创建规则

1. 打开 [Cloudflare Dashboard](https://dash.cloudflare.com) → 选中域名 **localedesk.cc**
2. 左侧 **Rules** → **Redirect Rules**（或 **Single Redirects**）
3. **Create rule**，例如命名：`www to apex`
4. **If**（匹配）：
   - Field: `Hostname`
   - Operator: `equals`
   - Value: `www.localedesk.cc`
5. **Then**（目标）：
   - Type: **Dynamic**（或 Static，若界面允许带 path）
   - Expression 示例（Dynamic）：  
     `concat("https://localedesk.cc", http.request.uri.path)`  
     若需保留 query：  
     `concat("https://localedesk.cc", http.request.uri.path, if(http.request.uri.query ne "", "?#{http.request.uri.query}", ""))`  
   - 或 Static：`https://localedesk.cc/`（仅首页时不够；优先 Dynamic 保留路径）
   - Status: **301**
6. Deploy / Save

`wrangler.toml` 里可继续保留 `www.localedesk.cc` 的 `custom_domain`，以便主机名解析到 CF 后由 Redirect Rule 生效。

## 验证

```bash
curl -sI https://www.localedesk.cc/ | head -n 20
# 期望：HTTP/2 301 且 Location: https://localedesk.cc/
curl -sI https://www.localedesk.cc/faq/ | head -n 20
# 期望：Location: https://localedesk.cc/faq/
```

创建完成后把结果记在此文件或学习笔记中即可。
