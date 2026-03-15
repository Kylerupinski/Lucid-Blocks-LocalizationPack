extends Node

func _init():
    # --- 注册翻译文件 ---
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
                    if file_name.ends_with(".csv") or file_name.ends_with(".translation"):
                        var translation = load(full_path)
                        if translation:
                            TranslationServer.add_translation(translation)
                            print("[语言管理器] 已注册翻译文件：", file_name)
                file_name = dir.get_next()
            dir.list_dir_end()
    
    # 设置当前语言
    TranslationServer.set_locale(TranslationServer.get_locale())
    print("[语言管理器] 当前语言：", TranslationServer.get_locale())
    
    # 延迟启动翻译监视器
    call_deferred("_start_translation_watcher")

func _start_translation_watcher():
    # 立即翻译当前所有控件
    _translate_all_controls(get_tree().root)
    
    # 监听新节点加入
    get_tree().node_added.connect(_on_node_added)
    
    # 定期全量扫描（1秒一次）
    var timer = Timer.new()
    timer.wait_time = 1.0
    timer.autostart = true
    timer.timeout.connect(_on_refresh_timer)
    add_child(timer)
    
    # 尝试连接设置按钮的点击信号
    call_deferred("_try_connect_settings_button")

func _on_refresh_timer():
    _translate_all_controls(get_tree().root)

func _on_node_added(node: Node):
    # 延迟两帧，确保节点完全初始化（_ready 已执行）
    call_deferred("_deferred_translate_node", node)

func _deferred_translate_node(node: Node):
    # 等待两帧
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_instance_valid(node):
        return
    _translate_node(node)

func _translate_node(node: Node):
    if node is Control:
        _translate_control(node)
    for child in node.get_children():
        _translate_node(child)

func _translate_control(control: Control):
    # ----- 处理标准 text 属性 -----
    if "text" in control:
        var current = control.text
        if current is String and current.length() > 0:
            var translated = tr(current)
            if translated != current:
                control.text = translated
    
    # ----- 处理 RichTextLabel 的 bbcode_text -----
    elif control is RichTextLabel:
        var current = control.bbcode_text
        if current.length() > 0:
            var translated = tr(current)
            if translated != current:
                control.bbcode_text = translated
    
    # ----- 处理 OptionButton 的弹出项文本 -----
    if control is OptionButton:
        for i in control.item_count:
            var item_text = control.get_item_text(i)
            if item_text.length() > 0:
                var translated = tr(item_text)
                if translated != item_text:
                    control.set_item_text(i, translated)
    
    # ----- 处理 TabContainer 的标签页标题 -----
    if control is TabContainer:
        for i in control.get_tab_count():
            var tab_title = control.get_tab_title(i)
            if tab_title.length() > 0:
                var translated = tr(tab_title)
                if translated != tab_title:
                    control.set_tab_title(i, translated)
    
    # ----- 处理 Tree 节点的文本-----
    if control is Tree:
        # 遍历所有 TreeItem
        var root_item = control.get_root()
        if root_item:
            _translate_tree_item(root_item)

func _translate_tree_item(item: TreeItem):
    if not item:
        return
    # 遍历所有列（通常列0是主文本，也有多列情况）
    for col in range(item.get_column_count()):
        var cell_text = item.get_text(col)
        if cell_text.length() > 0:
            var translated = tr(cell_text)
            if translated != cell_text:
                item.set_text(col, translated)
    # 递归子项
    var child = item.get_children()
    while child:
        _translate_tree_item(child)
        child = child.get_next()

func _translate_all_controls(node: Node):
    if node is Control:
        _translate_control(node)
    for child in node.get_children():
        _translate_all_controls(child)

# ----- 主菜单及设置按钮信号连接 -----
func _try_connect_settings_button():
    var main_menu = _find_main_menu()
    if main_menu:
        var settings_btn = main_menu.find_child("SettingsButton", true, false) or main_menu.get_node_or_null("%SettingsButton")
        if settings_btn and settings_btn.has_signal("pressed"):
            if not settings_btn.is_connected("pressed", _on_settings_pressed):
                settings_btn.pressed.connect(_on_settings_pressed)
                print("[语言管理器] 已连接设置按钮信号")
    else:
        # 没找到，1秒后重试
        await get_tree().create_timer(1.0).timeout
        _try_connect_settings_button()

func _on_settings_pressed():
    print("[语言管理器] 设置按钮被点击，立即刷新所有文本")
    _translate_all_controls(get_tree().root)

func _find_main_menu():
    # 按节点名查找
    var root = get_tree().root
    for child in root.get_children():
        if child.name == "MainMenu":
            return child
    # 递归按类名查找
    return _find_node_by_class(root, "MainMenu")

func _find_node_by_class(node: Node, class_string: String) -> Node:
    if node.get_class() == class_string or (node.has_method("get_class") and node.get_class() == class_string):
        return node
    for child in node.get_children():
        var found = _find_node_by_class(child, class_string)
        if found:
            return found
    return null
