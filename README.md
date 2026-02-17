# My Flash Site 使用指南

这是一个基于 Docker 和 Nginx 构建的 Flash 游戏库项目。它利用 [Ruffle](https://ruffle.rs/) 模拟器在现代浏览器中运行 Flash 游戏 (`.swf` 文件)，并提供了简单的游戏列表和带有基本认证的安全访问。

## 目录结构

```
my-flash-site/
├── docker-compose.yml          # Docker 服务配置文件
├── 生成html下的index.html命令    # 扫描游戏文件并生成 index.html 的脚本
├── 生成认证用户和密码            # 生成 .htpasswd 密码文件的命令
└── html/                       # 网站根目录
    ├── default.conf            # Nginx 配置文件
    ├── player.html             # 游戏播放器页面
    ├── ruffle/                 # Ruffle 模拟器核心文件
    └── games/                  # (挂载目录) 存放 .swf 游戏文件
```

## 前置要求

- 必须安装 [Docker](https://www.docker.com/) 和 [Docker Compose](https://docs.docker.com/compose/)。
- 建议在 Linux 环境或支持 Shell 脚本的环境 (如 Windows WSL 或 Git Bash) 下操作。

## 快速开始

### 1. 配置游戏路径

打开 `docker-compose.yml` 文件，找到 `volumes` 部分：

```yaml
volumes:
  # ...
  # 修改下方冒号前的路径为你本地存放 .swf 文件的实际路径
  - /path/to/your/games:/usr/share/nginx/html/games:ro
  # ...
```

同时，你需要修改 `生成html下的index.html命令` 脚本中的路径，使其与你本地的游戏路径一致，以便脚本能正确扫描到文件：

```bash
# 修改此行中的路径为你本地的实际路径
find /path/to/your/games -name "*.swf" | while read filepath; do
    # ...
    # 修改此行中的路径前缀，确保替换逻辑正确
    relpath=$(echo "$filepath" | sed 's|/path/to/your/games|games|')
    # ...
done
```

### 2. 生成认证密码

为了保护你的游戏库不被随意访问，项目启用了 HTTP 基本认证。

在项目根目录下运行以下命令生成密码文件 `.htpasswd` (默认用户名为 `root`，密码为 `passwd`)：

```bash
# 注意：此命令会覆盖旧的密码文件
docker run --rm -it httpd:alpine htpasswd -cb /dev/stdout root passwd > html/.htpasswd
```

如果你想修改用户名或密码，请将命令中的 `root` 和 `passwd` 替换为你想要的值。

### 3. 生成游戏列表

运行以下脚本扫描游戏目录并生成 `html/index.html` 文件：

```bash
sh 生成html下的index.html命令
```

### 4. 启动服务

在项目根目录下运行：

```bash
docker-compose up -d
```

### 5. 访问游戏库

打开浏览器访问：`http://localhost:48058`

- 输入你设置的用户名和密码 (默认: `root` / `passwd`)。
- 点击列表中的游戏即可开始游玩。

## 维护与更新

- **添加新游戏**：将 `.swf` 文件放入你挂载的游戏目录中，然后重新运行步骤 3 中的生成脚本即可更新列表，无需重启 Docker 容器。
- **修改 Nginx 配置**：如果修改了 `html/default.conf`，需要重启容器生效：`docker-compose restart`。

## 注意事项

- 本项目使用 Ruffle 模拟 Flash，虽然兼容性很高，但仍可能存在部分复杂游戏无法完美运行的情况。
- 确保端口 `48058` 未被占用。如需修改端口，请编辑 `docker-compose.yml` 中的 `ports` 映射。
