extends Node

const is_on := true

var _regex_digits := RegEx.new()
var _regex_placeholder := RegEx.new()

# 图片本地化重映射表：{ "原始文件stem": { "locale_code": "完整res路径" } }
var _image_remaps: Dictionary = {}

func _init():
    _regex_digits.compile("\\d+")
    _regex_placeholder.compile("%d")

    print("[语言管理器] 已成功加载，开启状态：", is_on)
    if is_on:
        # 注册翻译文件
        var mod_root = get_script().get_path().get_base_dir()
        var loc_dir = mod_root.path_join("localization")
        
        if DirAccess.dir_exists_absolute(loc_dir):
            var dir = DirAccess.open(loc_dir)
            if dir:
                dir.list_dir_begin()
                var file_name = dir.get_next()
                while file_name != "":
                    var full_path = loc_dir.path_join(file_name)
                    if not dir.current_is_dir():
                        if file_name.ends_with(".translation"):
                            var translation = load(full_path)
                            if translation:
                                TranslationServer.add_translation(translation)
                                print("[语言管理器] 已注册翻译文件：", file_name)
                    file_name = dir.get_next()
                dir.list_dir_end()
        
        TranslationServer.set_locale(TranslationServer.get_locale())
        print("[语言管理器] 当前语言：", TranslationServer.get_locale())
        
        call_deferred("_start_translation_watcher")
        call_deferred("_connect_level_up_menu")
        _build_image_remap_table()

func _start_translation_watcher():
    _translate_all_controls(get_tree().root)
    get_tree().node_added.connect(_on_node_added)
    _apply_image_remaps_to_node(get_tree().root)
    
# 连接 LevelUpMenu 的 visibility_changed 信号
func _connect_level_up_menu():
    var level_up_menu = get_tree().root.find_child("LevelUpMenu", true, false)
    if level_up_menu:
        var visibility_cb = Callable(self, "_on_level_up_visibility_changed").bind(level_up_menu)
        if not level_up_menu.is_connected("visibility_changed", visibility_cb):
            level_up_menu.connect("visibility_changed", visibility_cb)

        _connect_level_up_buttons(level_up_menu)

# 连接 LevelUpMenu 中的左右切换按钮
func _connect_level_up_buttons(menu: Node):
    var left_btn = menu.find_child("LeftButton", true, false)
    if left_btn == null:
        left_btn = menu.get_node_or_null("%LeftButton")
    var right_btn = menu.find_child("RightButton", true, false)
    if right_btn == null:
        right_btn = menu.get_node_or_null("%RightButton")
    
    if left_btn and left_btn.has_signal("pressed"):
        var left_cb = Callable(self, "_on_level_up_button_pressed").bind(menu)
        if not left_btn.is_connected("pressed", left_cb):
            left_btn.connect("pressed", left_cb)
    if right_btn and right_btn.has_signal("pressed"):
        var right_cb = Callable(self, "_on_level_up_button_pressed").bind(menu)
        if not right_btn.is_connected("pressed", right_cb):
            right_btn.connect("pressed", right_cb)

func _on_level_up_button_pressed(menu: Node):
    _translate_all_controls(menu)

func _on_level_up_visibility_changed(menu: Node):
    if menu.visible:
        # 延迟0.1秒刷新，确保界面元素已完全加载
        await get_tree().create_timer(0.1).timeout
        if is_instance_valid(menu) and menu.visible:
            _translate_all_controls(menu)

func _on_node_added(node: Node):
    call_deferred("_deferred_translate_node", node)

func _deferred_translate_node(node: Node):
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_instance_valid(node):
        return
    _translate_node(node)
    _apply_image_remaps_to_node(node)

func _translate_node(node: Node):
    if node is Control:
        _translate_control(node)
    for child in node.get_children():
        _translate_node(child)

# ---------- 核心翻译函数 ----------
func _translate_control(control: Control):
    # ----- 标准 text 属性 -----
    if "text" in control:
        var current = control.text
        if current is String and current.length() > 0:
            var translated = tr(current)
            if translated != current:
                control.text = translated
            else:
                # 尝试数字替换翻译
                _try_translate_with_digit(control)
    
    # ----- RichTextLabel 的 bbcode_text -----
    elif control is RichTextLabel:
        var current = control.bbcode_text
        if current.length() > 0:
            var translated = tr(current)
            if translated != current:
                control.bbcode_text = translated
            else:
                _try_translate_rich_with_digit(control)
    
    # ----- OptionButton 下拉项 -----
    if control is OptionButton:
        for i in range(control.item_count):
            var item_text = control.get_item_text(i)
            if item_text.length() > 0:
                var translated = tr(item_text)
                if translated != item_text:
                    control.set_item_text(i, translated)
    
    # ----- TabContainer 标签页标题 -----
    if control is TabContainer:
        for i in range(control.get_tab_count()):
            var tab_title = control.get_tab_title(i)
            if tab_title.length() > 0:
                var translated = tr(tab_title)
                if translated != tab_title:
                    control.set_tab_title(i, translated)
    
    # ----- Tree 节点文本 -----
    if control is Tree:
        var root_item = control.get_root()
        if root_item:
            _translate_tree_item(root_item)

# ---------- 数值动态翻译函数 ----------
func _try_translate_with_digit(control: Control):
    var result = _translate_text_with_digits(control.text)
    if result.changed:
        control.text = result.text

func _try_translate_rich_with_digit(control: RichTextLabel):
    # 与普通 Label 类似，但操作 bbcode_text
    var result = _translate_text_with_digits(control.bbcode_text, true)
    if result.changed:
        control.bbcode_text = result.text

func _translate_text_with_digits(text: String, skip_non_ascii := false) -> Dictionary:
    if skip_non_ascii and _contains_non_ascii(text):
        return {"changed": false, "text": text}

    var matches = _regex_digits.search_all(text)
    if matches.is_empty():
        return {"changed": false, "text": text}

    var numbers = []
    var template_parts = []
    var last_idx = 0
    for match in matches:
        var start = match.get_start()
        var end = match.get_end()
        template_parts.append(text.substr(last_idx, start - last_idx))
        template_parts.append("%d")
        numbers.append(int(match.get_string()))
        last_idx = end

    template_parts.append(text.substr(last_idx))
    var template = "".join(template_parts)

    var translated_template = tr(template)
    if translated_template == template:
        return {"changed": false, "text": text}

    var placeholder_count = _count_placeholders(translated_template)
    if placeholder_count != numbers.size():
        return {"changed": false, "text": text}

    var final_text
    if placeholder_count == 1:
        final_text = translated_template % numbers[0]
    else:
        final_text = translated_template % numbers

    return {"changed": true, "text": final_text}

func _contains_non_ascii(s: String) -> bool:
    for c in s:
        if c.unicode_at(0) > 127:
            return true
    return false

func _count_placeholders(s: String) -> int:
    return _regex_placeholder.search_all(s).size()

func _translate_tree_item(item: TreeItem):
    if not item:
        return
    for col in range(item.get_column_count()):
        var cell_text = item.get_text(col)
        if cell_text.length() > 0:
            var translated = tr(cell_text)
            if translated != cell_text:
                item.set_text(col, translated)

    var child = item.get_children()
    while child:
        _translate_tree_item(child)
        child = child.get_next()

func _translate_all_controls(node: Node):
    if node is Control:
        _translate_control(node)
    for child in node.get_children():
        _translate_all_controls(child)

# ---------- 图片本地化重映射 ----------
func _build_image_remap_table() -> void:
    var mod_root = get_script().get_path().get_base_dir()
    var loc_dir = mod_root.path_join("localization")
    _scan_image_remaps_in_dir(loc_dir)

func _scan_image_remaps_in_dir(dir_path: String) -> void:
    var dir = DirAccess.open(dir_path)
    if not dir:
        return
    dir.list_dir_begin()
    var entry = dir.get_next()
    while entry != "":
        var full_path = dir_path.path_join(entry)
        if dir.current_is_dir():
            _scan_image_remaps_in_dir(full_path)
        else:
            var ext = entry.get_extension().to_lower()
            if ext in ["png", "jpg", "jpeg", "webp", "svg"]:
                var stem = entry.get_basename()  # 例：tutorial_menu2-zh_cn
                var dash_pos = stem.rfind("-")
                if dash_pos > 0:
                    var original_stem = stem.substr(0, dash_pos)   # tutorial_menu2
                    var locale_code = stem.substr(dash_pos + 1).to_lower()  # zh_cn
                    if not _image_remaps.has(original_stem):
                        _image_remaps[original_stem] = {}
                    _image_remaps[original_stem][locale_code] = full_path
                    print("[语言管理器] 注册图片重映射：", original_stem, " [", locale_code, "] -> ", full_path)
        entry = dir.get_next()
    dir.list_dir_end()

func _apply_image_remaps_to_node(node: Node) -> void:
    if _image_remaps.is_empty():
        return
    _remap_node_texture(node)
    for child in node.get_children():
        _apply_image_remaps_to_node(child)

func _remap_node_texture(node: Node) -> void:
    if not "texture" in node:
        return
    var tex = node.get("texture")
    if not tex or not (tex is Texture2D):
        return
    var tex_path: String = tex.resource_path
    if tex_path.is_empty():
        return

    var tex_stem: String = tex_path.get_file().get_basename()
    if not _image_remaps.has(tex_stem):
        return

    var locale_map: Dictionary = _image_remaps[tex_stem]
    var locale: String = TranslationServer.get_locale().to_lower().replace("-", "_")  # zh_CN -> zh_cn
    var locale_lang: String = locale.split("_")[0]  # zh

    var remap_path: String = ""
    if locale_map.has(locale):
        remap_path = locale_map[locale]
    elif locale_map.has(locale_lang):
        remap_path = locale_map[locale_lang]
    else:
        for key in locale_map.keys():
            if key.begins_with(locale_lang + "_"):
                remap_path = locale_map[key]
                break

    if remap_path.is_empty() or tex_path == remap_path:
        return

    var new_tex = load(remap_path)
    if new_tex:
        node.set("texture", new_tex)
        print("[语言管理器] 图片已替换：", tex_stem, " -> ", remap_path)
