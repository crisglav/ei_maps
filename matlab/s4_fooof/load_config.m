function config = load_config(json_path)
    txt = fileread(json_path);
    config = jsondecode(txt);
end