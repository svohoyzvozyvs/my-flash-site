#!/bin/bash
# 生成保留目录分类结构的 index.html
# 在服务器上运行（docker 容器内或直接在宿主机）

# 游戏根目录（在宿主机上的路径）
GAME_ROOT="/root/data/docker_data/openlist/data/openlist/download/小游戏合集（未压缩）"
# 输出文件
OUTPUT="html/index.html"
# web 路径前缀（对应 docker-compose 中的挂载路径）
WEB_PREFIX="games"

# 日志函数：输出到 stderr，不影响 stdout
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

log "🚀 开始生成 index.html"
log "📂 游戏根目录: $GAME_ROOT"
log "📄 输出文件: $OUTPUT"

# ============ 写入 HTML 头部 ============
log "✍️  写入 HTML 头部..."
cat > "$OUTPUT" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎮 Flash 游戏库</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            color: #e0e0e0;
            min-height: 100vh;
            padding: 20px;
        }
        .header {
            text-align: center;
            padding: 30px 0;
        }
        .header h1 {
            font-size: 2.2em;
            background: linear-gradient(90deg, #ff6b6b, #feca57, #48dbfb, #ff9ff3);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-shadow: none;
        }
        .header p { color: #aaa; margin-top: 8px; }
        .search-box {
            max-width: 500px;
            margin: 20px auto;
            position: relative;
        }
        .search-box input {
            width: 100%;
            padding: 12px 20px 12px 45px;
            border: 2px solid #444;
            border-radius: 25px;
            background: rgba(255,255,255,0.08);
            color: #fff;
            font-size: 16px;
            outline: none;
            transition: border-color 0.3s;
        }
        .search-box input:focus { border-color: #48dbfb; }
        .search-box::before {
            content: '🔍';
            position: absolute;
            left: 16px;
            top: 50%;
            transform: translateY(-50%);
            font-size: 18px;
        }
        .toolbar {
            text-align: center;
            margin: 15px 0;
        }
        .toolbar button {
            padding: 8px 18px;
            margin: 4px;
            border: 1px solid #555;
            border-radius: 15px;
            background: rgba(255,255,255,0.06);
            color: #ccc;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.2s;
        }
        .toolbar button:hover { background: rgba(255,255,255,0.15); color: #fff; }
        .content { max-width: 900px; margin: 0 auto; }
        details {
            margin: 8px 0;
            background: rgba(255,255,255,0.04);
            border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.08);
            overflow: hidden;
            transition: all 0.2s;
        }
        details:hover { border-color: rgba(255,255,255,0.15); }
        details[open] > summary { border-bottom: 1px solid rgba(255,255,255,0.08); }
        summary {
            padding: 12px 18px;
            cursor: pointer;
            font-weight: bold;
            font-size: 16px;
            list-style: none;
            display: flex;
            align-items: center;
            gap: 10px;
            user-select: none;
            transition: background 0.2s;
        }
        summary:hover { background: rgba(255,255,255,0.06); }
        summary::before { content: '📁'; }
        details[open] > summary::before { content: '📂'; }
        summary .count {
            margin-left: auto;
            font-size: 12px;
            font-weight: normal;
            color: #888;
            background: rgba(255,255,255,0.08);
            padding: 2px 10px;
            border-radius: 10px;
        }
        /* 顶层分类用不同颜色 */
        .content > details > summary { font-size: 18px; }
        .content > details:nth-child(1) > summary { color: #ff6b6b; }
        .content > details:nth-child(2) > summary { color: #feca57; }
        .content > details:nth-child(3) > summary { color: #48dbfb; }
        .inner { padding: 5px 10px 10px 10px; }
        .game-list { list-style: none; padding: 0; }
        .game-list li { margin: 3px 0; }
        .game-list a {
            display: block;
            padding: 8px 14px;
            color: #ddd;
            text-decoration: none;
            border-radius: 6px;
            transition: all 0.15s;
            font-size: 14px;
        }
        .game-list a::before { content: '🎮 '; }
        .game-list a:hover {
            background: rgba(72, 219, 251, 0.15);
            color: #48dbfb;
            transform: translateX(5px);
        }
        .no-result {
            text-align: center;
            color: #888;
            padding: 30px;
            display: none;
        }
        @media (max-width: 600px) {
            body { padding: 10px; }
            .header h1 { font-size: 1.5em; }
            summary { font-size: 14px !important; padding: 10px 12px; }
            .game-list a { padding: 6px 10px; font-size: 13px; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎮 Flash 游戏库</h1>
        <p id="total-count"></p>
    </div>
    <div class="search-box"><input type="text" id="search" placeholder="搜索游戏名称..." autocomplete="off"></div>
    <div class="toolbar">
        <button onclick="toggleAll(true)">📂 全部展开</button>
        <button onclick="toggleAll(false)">📁 全部折叠</button>
    </div>
    <div class="content" id="content">
HTMLHEAD

# ============ 递归生成目录结构函数 ============
generate_dir() {
    local dir="$1"
    local rel_base="$2"  # 相对于 GAME_ROOT 的路径，用于构建 web 路径
    local dir_display="${rel_base:-ROOT}"
    log "  📂 扫描目录: $dir_display"

    local has_content=false
    local swf_files=()
    local sub_dirs=()

    # 收集该目录下的 swf 文件和子目录
    while IFS= read -r -d '' entry; do
        local name=$(basename "$entry")
        if [ -d "$entry" ]; then
            sub_dirs+=("$entry")
        elif [[ "$name" == *.swf ]]; then
            swf_files+=("$entry")
        fi
    done < <(find "$dir" -maxdepth 1 -mindepth 1 \( -type f -name '*.swf' -o -type d \) -print0 | sort -z)

    # 如果没有内容则跳过
    if [ ${#swf_files[@]} -eq 0 ] && [ ${#sub_dirs[@]} -eq 0 ]; then
        return
    fi

    log "     ├─ 发现 ${#swf_files[@]} 个 .swf 文件, ${#sub_dirs[@]} 个子目录"

    # 输出 swf 文件列表
    if [ ${#swf_files[@]} -gt 0 ]; then
        echo '<ul class="game-list">' >> "$OUTPUT"
        for swf in "${swf_files[@]}"; do
            local filename=$(basename "$swf")
            local gamename="${filename%.swf}"
            local webpath
            if [ -n "$rel_base" ]; then
                webpath="${WEB_PREFIX}/${rel_base}/${filename}"
            else
                webpath="${WEB_PREFIX}/${filename}"
            fi
            # URL 编码路径
            local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$webpath'))")
            echo "<li><a href='player.html?game=${encoded}' target='_blank'>${gamename}</a></li>" >> "$OUTPUT"
        done
        echo '</ul>' >> "$OUTPUT"
    fi

    # 递归处理子目录
    for subdir in "${sub_dirs[@]}"; do
        local dirname=$(basename "$subdir")
        local new_rel
        if [ -n "$rel_base" ]; then
            new_rel="${rel_base}/${dirname}"
        else
            new_rel="${dirname}"
        fi

        # 计算该子目录下 swf 文件总数
        local count=$(find "$subdir" -name '*.swf' -type f | wc -l)
        if [ "$count" -eq 0 ]; then
            log "     ├─ 跳过(无swf): $dirname"
            continue
        fi

        log "     ├─ 📁 子分类: $dirname ($count 个游戏)"
        echo "<details>" >> "$OUTPUT"
        echo "<summary>${dirname} <span class='count'>${count} 个游戏</span></summary>" >> "$OUTPUT"
        echo '<div class="inner">' >> "$OUTPUT"

        generate_dir "$subdir" "$new_rel"

        echo '</div>' >> "$OUTPUT"
        echo '</details>' >> "$OUTPUT"
    done
}

# ============ 生成三个顶层分类 ============
# 定义顶层目录
TOP_DIRS=("更新" "万款小游戏合集" "flash 160＋款怀旧小游戏")

for top in "${TOP_DIRS[@]}"; do
    top_path="${GAME_ROOT}/${top}"
    if [ ! -d "$top_path" ]; then
        log "⚠️  警告: 目录不存在: $top_path"
        continue
    fi

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "📦 处理顶层分类: $top"
    count=$(find "$top_path" -name '*.swf' -type f | wc -l)
    log "   共 $count 个 .swf 文件"

    echo "<details open>" >> "$OUTPUT"
    echo "<summary>${top} <span class='count'>${count} 个游戏</span></summary>" >> "$OUTPUT"
    echo '<div class="inner">' >> "$OUTPUT"

    generate_dir "$top_path" "$top"

    echo '</div>' >> "$OUTPUT"
    echo '</details>' >> "$OUTPUT"
done

# ============ 写入 HTML 尾部（含搜索 JS） ============
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "✍️  写入 HTML 尾部和 JS 代码..."
cat >> "$OUTPUT" << 'HTMLTAIL'
    </div>
    <div class="no-result" id="no-result">😔 没有找到匹配的游戏</div>

    <script>
        // 统计游戏总数
        const totalGames = document.querySelectorAll('.game-list a').length;
        document.getElementById('total-count').textContent = `共收录 ${totalGames} 款 Flash 游戏`;

        // 搜索功能
        const searchInput = document.getElementById('search');
        const content = document.getElementById('content');
        const noResult = document.getElementById('no-result');

        searchInput.addEventListener('input', function() {
            const keyword = this.value.trim().toLowerCase();
            const allLinks = content.querySelectorAll('.game-list a');
            const allDetails = content.querySelectorAll('details');
            let matchCount = 0;

            if (!keyword) {
                // 清空搜索：显示全部，恢复折叠状态
                allLinks.forEach(a => a.parentElement.style.display = '');
                allDetails.forEach(d => { d.style.display = ''; d.removeAttribute('open'); });
                // 顶层默认展开
                content.querySelectorAll(':scope > details').forEach(d => d.setAttribute('open', ''));
                noResult.style.display = 'none';
                return;
            }

            // 先隐藏所有
            allLinks.forEach(a => a.parentElement.style.display = 'none');
            allDetails.forEach(d => { d.style.display = 'none'; d.removeAttribute('open'); });

            // 显示匹配项
            allLinks.forEach(a => {
                if (a.textContent.toLowerCase().includes(keyword)) {
                    a.parentElement.style.display = '';
                    matchCount++;
                    // 递归展开父级 details
                    let parent = a.closest('details');
                    while (parent) {
                        parent.style.display = '';
                        parent.setAttribute('open', '');
                        parent = parent.parentElement.closest('details');
                    }
                }
            });

            noResult.style.display = matchCount === 0 ? 'block' : 'none';
        });

        // 全部展开/折叠
        function toggleAll(open) {
            content.querySelectorAll('details').forEach(d => {
                if (open) d.setAttribute('open', '');
                else d.removeAttribute('open');
            });
        }

        // 默认展开顶层
        content.querySelectorAll(':scope > details').forEach(d => d.setAttribute('open', ''));
    </script>
</body>
</html>
HTMLTAIL

total=$(find "$GAME_ROOT" -name '*.swf' -type f | wc -l)
log ""
log "✅ 完成！index.html 已生成到 $OUTPUT"
log "📊 总计 $total 个 .swf 游戏文件"
