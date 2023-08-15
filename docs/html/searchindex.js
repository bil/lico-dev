Search.setIndex({"docnames": ["advanced/custom_drivers", "advanced/debugging", "advanced/index", "api/cli", "api/env_vars", "api/index", "api/python", "api/yaml_config", "basic/directory_structure", "basic/drivers", "basic/index", "basic/modules", "basic/parsers", "developers/contributing", "developers/env_setup", "developers/index", "developers/packaging", "guide/examples", "guide/index", "guide/quickstart", "guide/tutorial", "index", "install/licorice", "install/python", "partials/_permissions", "partials/_rt_setup", "realtime"], "filenames": ["advanced/custom_drivers.rst", "advanced/debugging.rst", "advanced/index.rst", "api/cli.rst", "api/env_vars.rst", "api/index.rst", "api/python.rst", "api/yaml_config.rst", "basic/directory_structure.rst", "basic/drivers.rst", "basic/index.rst", "basic/modules.rst", "basic/parsers.rst", "developers/contributing.rst", "developers/env_setup.rst", "developers/index.rst", "developers/packaging.rst", "guide/examples.rst", "guide/index.rst", "guide/quickstart.rst", "guide/tutorial.rst", "index.rst", "install/licorice.rst", "install/python.rst", "partials/_permissions.rst", "partials/_rt_setup.rst", "realtime.rst"], "titles": ["Custom Drivers", "Debugging Models", "Advanced Usage", "LiCoRICE CLI", "Environment Variables", "LiCoRICE API Reference", "LiCoRICE Python API", "YAML Configuration Reference", "Directory Structure", "Drivers", "Basic Usage", "Writing Module Processes", "Parsers", "Contributing", "Development Environment Setup", "Developer Guide", "Packaging", "LiCoRICE Examples", "User Guide", "LiCoRICE Quickstart", "LiCoRICE Tutorial", "LiCoRICE Documentation", "Installation", "Installing Python and virtualenv", "&lt;no title&gt;", "&lt;no title&gt;", "Why Realtime?"], "terms": {"user": [0, 3, 6, 7, 8, 9, 11, 12, 14, 17, 19, 21, 22, 24, 26], "mai": [0, 8, 9, 11, 14, 19, 20, 22, 25, 26], "extend": [0, 2], "licoric": [0, 1, 2, 4, 7, 8, 9, 11, 12, 13, 14, 16, 18, 22, 23, 24, 25, 26], "write": [0, 3, 7, 9, 10, 21], "own": [0, 20], "interfac": [0, 6, 9], "peripher": [0, 14, 22, 25], "For": [0, 11, 14, 19, 22, 25], "now": [0, 14, 19, 20, 22, 24], "sink": [0, 7, 9, 10, 11, 17, 19, 20], "must": [0, 3, 6, 11, 17, 19, 26], "ad": [0, 17, 19], "templat": [0, 1, 3, 4, 9], "sink_driv": [0, 9], "folder": [0, 16], "sourc": [0, 7, 9, 10, 11, 14, 17, 19, 23], "_driver": 0, "eventu": 0, "abl": [0, 19], "add": [0, 12, 14, 18, 22, 24], "set": [0, 4, 7, 8, 11, 14, 17, 20, 22, 24], "an": [0, 1, 7, 12, 13, 14, 16, 17, 18, 20, 22, 25], "environ": [0, 3, 5, 8, 13, 15, 17, 19, 20, 21, 23], "variabl": [0, 3, 5, 7, 8, 9, 11, 17, 19, 20, 21], "The": [0, 3, 4, 5, 6, 7, 11, 12, 14, 17, 19, 20, 22, 23, 25, 26], "follow": [0, 4, 7, 8, 12, 13, 14, 17, 19, 20, 22], "i": [0, 3, 4, 6, 7, 8, 9, 11, 12, 14, 16, 17, 19, 20, 21, 22, 23, 25], "implement": [0, 7, 11, 13, 17, 20], "parallel": [0, 17, 19], "port": [0, 14, 17, 18, 19, 22, 25], "which": [0, 3, 7, 9, 11, 12, 14, 19, 20, 22, 25], "us": [0, 2, 4, 5, 6, 7, 9, 11, 12, 14, 17, 19, 20, 22, 23, 24, 25], "pyparallel": 0, "read": [0, 3, 7, 9, 17, 19], "data": [0, 7, 9, 12, 17, 19, 20, 26], "each": [0, 3, 11, 12, 19], "tick": [0, 3, 7, 9, 11, 12, 14, 17, 19, 20, 22, 25], "It": [0, 12, 17, 19, 20], "four": 0, "code": [0, 1, 3, 6, 7, 8, 9, 11, 12, 20, 21, 26], "section": [0, 2, 7, 11, 12, 18, 20, 26], "import": [0, 14, 20, 22, 25], "setup": [0, 7, 13, 15, 16, 21, 23], "omit": 0, "one": [0, 7, 9, 12, 14, 17, 19, 20, 22, 25], "exit_handl": 0, "ar": [0, 1, 2, 3, 6, 7, 11, 12, 13, 14, 17, 19, 20, 21, 22, 24, 25, 26], "directli": [0, 19], "drop": 0, "jinja2": 0, "note": [0, 14, 19, 22, 25], "can": [0, 1, 3, 5, 6, 7, 9, 12, 14, 16, 17, 19, 22, 24, 25, 26], "also": [0, 7, 9, 12, 19, 20], "itself": [0, 1], "In": [0, 11, 12, 14, 19, 22, 25, 26], "thi": [0, 2, 3, 4, 5, 6, 7, 8, 9, 12, 14, 16, 17, 18, 19, 20, 21, 22, 25, 26], "instanc": 0, "async": [0, 7, 10, 12, 20], "flag": [0, 6, 9, 17, 19], "ensur": [0, 14, 20, 22, 24], "modul": [0, 3, 4, 8, 10, 12, 17, 18, 21], "call": [0, 6, 17, 19], "happen": 0, "most": [0, 20], "twice": 0, "per": [0, 3], "sinc": [0, 19, 26], "sleep_dur": 0, "half": 0, "length": [0, 19], "exact": 0, "same": [0, 6, 19, 20], "synchron": [0, 9], "sleep": 0, "skip": 0, "onc": [0, 19, 23], "__driver_code__": 0, "cdef": 0, "unsign": [0, 19], "char": 0, "inval": 0, "pport": 0, "in_sign": 0, "arg": [0, 7, 12, 19, 20], "addr": [0, 19], "setdatadir": 0, "fals": [0, 19, 20], "from": [0, 3, 4, 6, 7, 12, 14, 16, 17, 18, 20, 22, 25], "pin": [0, 17, 19], "ppdatadir": 0, "config": [0, 3, 6, 11, 14, 20], "tick_len": [0, 7, 19, 20], "2": [0, 7, 14, 18, 20, 25], "1e6": 0, "getdata": 0, "inbuf": [0, 12], "0": [0, 7, 11, 12, 14, 18, 22, 25], "endif": 0, "realtim": [1, 3, 7, 9, 14, 17, 19, 21, 24, 25], "applic": [1, 2, 7, 14, 22, 25, 26], "challeng": 1, "mani": 1, "bug": 1, "aris": 1, "while": [1, 19, 21], "run": [1, 4, 6, 7, 9, 11, 12, 13, 14, 16, 17, 21, 22, 23, 24, 25], "have": [1, 7, 14, 17, 19, 20, 22, 24], "do": [1, 12, 14, 19, 20, 22, 23, 25], "time": [1, 3, 7, 11, 14, 17, 19, 20, 21, 25, 26], "result": 1, "race": 1, "condit": 1, "when": [1, 11, 14, 16, 20, 22, 25, 26], "make": [1, 3, 13, 17, 19, 20, 22, 26], "sure": [1, 13, 17, 19, 20, 22], "look": [1, 2, 4, 17, 19], "file": [1, 3, 4, 6, 7, 8, 11, 14, 17, 20, 22, 23, 24], "creat": [1, 6, 8, 9, 11, 13, 14, 16, 20, 22, 23, 24], "output": [1, 3, 4, 7, 9, 11, 12, 17, 18, 20], "directori": [1, 3, 9, 10, 14, 16, 18, 19, 20, 21, 22, 25], "These": [1, 17, 19], "render": [1, 3, 4], "actual": [1, 7], "compil": [1, 4, 6, 14, 17, 19, 20, 21, 22, 25], "often": [1, 17], "much": [1, 7], "easier": 1, "than": [1, 12, 22], "core": [1, 6, 7, 17], "If": [1, 12, 14, 16, 17, 19, 20, 22, 25], "you": [1, 2, 14, 17, 18, 19, 20, 22, 23, 24, 25], "idea": 1, "about": [1, 19], "how": [1, 5, 7, 12, 17, 19, 23], "made": 1, "pleas": [1, 11, 17], "post": 1, "issu": [1, 4, 16, 19], "consid": [1, 12], "contribut": [1, 15, 21, 22], "assum": [2, 19, 20, 23], "re": [2, 17, 19, 20, 22, 23], "alreadi": [2, 19], "comfort": 2, "basic": [2, 14, 19, 21, 25], "case": [2, 7, 19], "model": [2, 3, 4, 6, 8, 11, 14, 18, 21, 22, 25], "beyond": 2, "system": [2, 7, 9, 11, 14, 17, 19, 21, 22, 25, 26], "default": [2, 3, 4, 6, 7, 8, 9, 12, 14, 16, 17, 19, 22, 25, 26], "optim": [2, 17], "your": [2, 4, 7, 8, 13, 14, 17, 19, 20, 22, 23, 24, 25], "custom": [2, 9, 21], "driver": [2, 10, 12, 17, 19, 20, 21], "exampl": [2, 14, 18, 19, 20, 21, 22, 25, 26], "debug": [2, 16, 17, 21], "model_nam": [3, 4], "level": [3, 7, 12, 14, 19, 21, 22, 25, 26], "python": [3, 4, 5, 7, 12, 14, 19, 20, 21, 22], "snippet": [3, 11], "includ": [3, 6, 9, 13, 14, 19, 26], "parser": [3, 7, 10, 19, 20, 21], "constructor": [3, 7, 8, 12, 19, 20], "destructor": [3, 7, 12, 20], "filenam": [3, 6], "taken": [3, 12, 19, 22], "definit": [3, 19, 20], "yaml": [3, 5, 6, 8, 11, 19, 20, 21], "configur": [3, 5, 21], "written": 3, "overridden": [3, 8], "licorice_module_path": [3, 4], "just": [3, 11, 19], "scaffold": [3, 6, 11], "fill": [3, 20], "out": [3, 4, 7, 11, 12, 14, 17, 18, 19, 22, 24, 26], "function": [3, 6, 12, 20], "valid": [3, 17], "construct": [3, 7, 17, 19], "ani": [3, 6, 7, 14, 17, 19, 20, 22, 23, 25], "need": [3, 7, 12, 14, 19, 20, 22, 25, 26], "licorice_output_dir": [3, 4], "current": [3, 4, 11, 20, 22], "clean": [3, 7], "all": [3, 7, 11, 14, 19, 20, 22, 25], "cython": 3, "c": [3, 7, 8, 19, 21], "execut": [3, 4, 16, 17, 19], "simpl": [3, 17, 18, 20], "timer": [3, 11, 17, 26], "right": 3, "prioriti": 3, "kick": 3, "off": [3, 19], "rest": [3, 19], "process": [3, 7, 9, 10, 17, 19, 21, 26], "combin": [3, 17], "behavior": [3, 4, 8, 19], "singl": [3, 7, 16, 19, 20, 26], "conveni": [3, 19], "licorice_export_dir": [3, 4], "full": [3, 6, 11, 19], "view": 3, "h": 3, "print": [3, 19], "below": [3, 12, 23], "usag": [3, 14, 21, 22, 24], "y": [3, 12, 19, 20, 22, 23], "rt": [3, 17], "working_path": [3, 4], "template_path": 3, "generator_path": 3, "module_path": 3, "model_path": 3, "output_dir": 3, "export_dir": 3, "tmp_module_dir": 3, "tmp_output_dir": 3, "posit": [3, 19, 20], "argument": [3, 6, 19], "name": [3, 7, 11, 12, 19, 20], "extens": [3, 6], "option": [3, 6, 14, 17, 23, 25], "help": [3, 17, 19], "show": [3, 17, 19], "messag": [3, 19], "exit": 3, "confirm": [3, 17], "bypass": 3, "action": [3, 7], "guarante": [3, 21, 22, 26], "overrid": [3, 4], "accept": 3, "json": 3, "input": [3, 7, 9, 11, 12, 17, 18], "path": [3, 6, 19, 23, 26], "licorice_working_path": [3, 4, 19, 20], "licorice_template_path": [3, 4], "licorice_generator_path": [3, 4], "licorice_model_path": [3, 4], "dir": 3, "licorice_tmp_module_dir": [3, 4], "licorice_tmp_output_dir": [3, 4], "search": 4, "instruct": [4, 13, 14, 17, 19, 22, 25], "where": [4, 11, 17, 19, 20], "certain": 4, "style": 4, "list": [4, 14, 17, 22, 25], "separ": [4, 19], "o": [4, 9], "e": [4, 7, 14, 17, 19, 21, 22, 25], "commonli": [4, 11, 20], "linux": [4, 17, 19, 23, 26], "base": [4, 21, 22], "work": [4, 14, 17, 19, 20, 22, 25], "ha": [4, 12, 19, 20, 26], "been": [4, 17, 26], "A": [4, 16, 17, 19], "warn": 4, "suppress": 4, "": [4, 7, 8, 9, 11, 12, 16, 17, 19, 20, 22, 23, 26], "repo": [4, 16], "gener": [4, 6, 12, 14, 22, 25, 26], "concaten": 4, "live": [4, 20], "given": [4, 6, 7, 8, 14, 22, 25, 26], "lico": [4, 19], "cli": [4, 5, 6, 21], "api": [4, 21], "export": [4, 6, 19, 22, 23], "move": [4, 17, 20], "old": [4, 20], "command": [4, 6, 17, 19, 20], "prevent": 4, "accident": 4, "delet": 4, "document": [5, 13], "branch": [5, 13, 16], "detail": [5, 6], "wrap": 6, "therefor": 6, "offer": [6, 22], "through": [6, 7, 12, 17, 18, 19], "programmat": 6, "test": [6, 14, 22, 23, 25, 26], "variat": 6, "generate_model": 6, "str": 6, "kwarg": 6, "none": [6, 7], "dict": [6, 7], "allow": [6, 7, 12, 19, 20, 21], "pass": [6, 7, 12, 18], "either": [6, 7, 19], "string": [6, 19], "well": [6, 19, 20, 23], "keyword": [6, 7], "paramet": 6, "access": [6, 17, 19], "yml": 6, "adher": 6, "refer": [6, 11, 17, 19, 21, 26], "load": 6, "manual": 6, "extra": 6, "return": [6, 19, 20], "parse_model": 6, "pars": [6, 19, 20], "compile_model": 6, "run_model": 6, "go": [6, 19, 20], "peform": 6, "success": [6, 20], "export_model": 6, "specifi": [7, 8, 9, 11, 12], "defin": [7, 9, 11, 12, 19, 20, 26], "architectur": 7, "analysi": 7, "pipelin": [7, 16], "acquisit": [7, 17], "broken": 7, "up": [7, 12, 14, 18, 22, 24], "high": [7, 19, 21], "here": [7, 11, 14, 19, 20, 22, 25], "we": [7, 8, 11, 17, 19, 20, 22, 23], "aspect": 7, "our": [7, 19], "metric": 7, "order": [7, 17, 26], "control": [7, 17, 19, 20, 26], "wai": [7, 12, 19], "interact": [7, 19], "real": 7, "world": [7, 18], "descript": [7, 11], "clock": [7, 9, 19, 26], "frequenc": [7, 19], "microsecond": [7, 19], "num_tick": [7, 19, 20], "number": [7, 9, 12, 14, 16, 19, 20, 22, 25, 26], "1": [7, 12, 14, 18, 20, 25], "indefinit": [7, 19, 20, 26], "sys_mask": 7, "cpu": 7, "bitmask": 7, "indic": 7, "avail": 7, "cpu0": 7, "g": [7, 14, 17, 22, 25], "0x1": 7, "mode": [7, 20], "0xff": 7, "8": [7, 18, 19, 23], "non": [7, 14, 20, 22, 24], "lico_mask": 7, "besid": 7, "0xfe": 7, "source_init_tick": [7, 19], "befor": [7, 17, 19, 20], "start": [7, 11, 19, 20], "module_init_tick": 7, "between": [7, 19], "keep": [7, 19], "over": [7, 19], "store": 7, "necessari": [7, 14, 17, 20, 22, 25], "At": 7, "repres": [7, 11, 12], "numpi": [7, 19, 22], "arrai": [7, 12, 19], "howev": [7, 20], "thei": [7, 20], "share": [7, 19], "memori": 7, "fast": [7, 19], "transfer": 7, "requir": [7, 14, 17, 19, 20, 22, 25, 26], "shape": [7, 19, 20], "tupl": 7, "dtype": [7, 12, 19, 20], "histori": [7, 19], "latenc": [7, 19], "fix": 7, "introduc": [7, 19], "ndarrai": 7, "index": [7, 11, 17], "log": [7, 14, 17, 18, 20, 22, 24, 26], "whether": 7, "log_storag": [7, 20], "specif": [7, 17, 19], "see": [7, 17, 19, 20], "primari": 7, "build": [7, 16, 19, 20], "block": [7, 11, 19, 21, 26], "languag": [7, 12, 19, 20], "what": [7, 19], "stream": 7, "prepar": 7, "initi": [7, 20], "stop": [7, 19], "automat": [7, 16, 19, 23], "detect": [7, 17], "intern": [7, 11, 12, 19, 20], "attribut": 7, "program": [7, 19, 26], "onli": [7, 12, 14, 17, 19, 20, 22, 25], "teardown": 7, "resourc": [7, 12], "inform": [7, 19], "should": [7, 14, 17, 19, 20, 22, 25], "ever": 7, "inher": 7, "complex": [7, 14, 17, 19, 22, 25], "deal": 7, "devic": [7, 14, 17, 19, 22, 25], "addit": [7, 9], "100000": 7, "until": [7, 19], "termin": [7, 19, 20], "10": [7, 18, 19], "signal_1": 7, "treat": [7, 12], "float64": 7, "previou": [7, 19], "signal_2": 7, "1d": 7, "sum_init": 7, "true": [7, 9, 12, 19, 20], "signifi": 7, "joystick": [7, 12, 18], "usb": [7, 14, 17, 20, 22, 25], "joystick_raw": [7, 12, 20], "type": [7, 11, 12, 19, 20], "pygame_joystick": [7, 12, 20], "schema": [7, 12, 19, 20], "max_packets_per_tick": [7, 19, 20], "sync": [7, 10], "doubl": [7, 11, 12, 20], "size": [7, 12, 19, 20], "sum": 7, "sum_print": 7, "recommend": [8, 17, 19, 23], "hous": 8, "manner": 8, "licorice_workspac": 8, "model_1": 8, "model_1_modul": 8, "py": [8, 16, 19, 20], "model_1_module_constructor": 8, "model_2": 8, "model_2_sourc": 8, "model_2_source_constructor": 8, "model_2_source_destructor": 8, "model_2_modul": 8, "shared_modul": 8, "shared_module_constructor": 8, "licorice_": [8, 17], "_path": 8, "_dir": 8, "concept": 9, "extern": [9, 12, 18], "give": 9, "abil": [9, 12], "support": [9, 14, 21, 22, 23, 25, 26], "found": 9, "under": [9, 17, 19, 20], "source_driv": 9, "By": 9, "insid": 9, "respect": 9, "asynchron": [9, 18], "signal": [9, 12, 17, 18, 20], "two": [9, 17, 19, 20], "reader": 9, "writer": 9, "handl": [9, 17, 26], "buffer": [9, 12], "anoth": [9, 19], "stamper": 9, "boundari": 9, "updat": [9, 16, 20, 22, 23], "housekeep": 9, "accord": 9, "structur": [10, 12, 18, 21], "common": [10, 26], "properti": 10, "v": 10, "comput": [11, 19, 20, 26], "take": [11, 12, 14, 17, 19, 22, 25, 26], "manipul": 11, "them": [11, 12, 17, 19], "respons": [11, 19], "term": 11, "overload": 11, "encompass": 11, "ambigu": 11, "syntact": 11, "check": [11, 19, 22], "surround": 11, "expos": 11, "some": [11, 19, 20, 26], "advantag": [11, 19], "time_tick": 11, "uint64_t": 11, "time_system": 11, "measur": [11, 17], "clock_gettim": 11, "clock_monoton": 11, "second": [11, 19], "nanosecond": 11, "resolut": 11, "convert": 12, "vice": 12, "versa": 12, "dimension": 12, "multipl": [12, 17, 19], "n": [12, 20, 23], "Or": [12, 14, 22], "pack": 12, "packet": 12, "differ": [12, 19, 23], "expect": 12, "match": [12, 20], "thought": 12, "similar": [12, 19, 20, 22], "provid": [12, 17, 19, 20], "spin": 12, "tear": 12, "down": [12, 19, 26], "suppli": 12, "joystick_read": [12, 20], "demo": [12, 17, 18], "uint8": [12, 19, 20], "22": [12, 20], "joystick_axi": [12, 20], "joystick_button": [12, 20], "element": 12, "shown": 12, "uint8_t": 12, "128": 12, "rang": [12, 20], "format": [12, 20], "mix": 12, "analog": [12, 17, 20], "stick": [12, 20], "x": [12, 17, 20], "coordin": 12, "enough": [12, 19], "button": [12, 19, 20], "first": [12, 16, 19, 20], "cast": 12, "valu": [12, 19, 20], "more": [12, 14, 17, 19, 22, 25], "readabl": 12, "flat": 12, "less": [12, 17], "opposit": 12, "To": [13, 14, 17, 19, 22, 24], "develop": [13, 21, 22, 24], "chang": [13, 14, 17, 19, 20, 22, 25], "pytest": 13, "local": [13, 19], "break": 13, "push": [13, 20], "open": [13, 19, 20], "mr": 13, "review": 13, "clone": [14, 17], "repositori": [14, 17, 22, 25], "git": [14, 22], "http": [14, 22, 23], "github": [14, 22], "com": [14, 22], "bil": [14, 22], "cd": 14, "virtualenv": [14, 20, 22], "top": [14, 19, 22, 25], "instal": [14, 17, 19, 20, 21, 25], "env_setup": [14, 23], "sh": [14, 16, 17, 22, 23, 25], "pyenv": 14, "shell": [14, 19, 23], "bash": [14, 19, 23], "cat": 14, "pyenv_config": 14, "bashrc": [14, 22, 23], "f": [14, 19], "bash_profil": 14, "els": [14, 19, 20], "profil": [14, 19], "fi": 14, "bind": 14, "newli": 14, "built": [14, 19, 20], "activ": [14, 20, 22, 23], "altern": 14, "version": [14, 16, 22, 25], "contain": [14, 16, 17], "echo": [14, 23], "correct": [14, 17, 22, 24], "permiss": [14, 22, 24], "new": [14, 19, 20, 22, 24], "limit": [14, 22, 24, 25], "sudo": [14, 17, 19, 20, 22, 23, 24], "vi": [14, 22, 24], "etc": [14, 22, 24], "secur": [14, 22, 24], "d": [14, 19, 22, 24], "conf": [14, 22, 24], "line": [14, 18, 19, 22, 24], "replac": [14, 22, 24], "rtprio": [14, 22, 24], "95": [14, 22, 24], "memlock": [14, 22, 24], "unlimit": [14, 22, 24], "nice": [14, 17, 22, 24], "20": [14, 20, 22, 24, 25], "back": [14, 17, 19, 20, 22, 24], "modifi": [14, 19, 22], "bio": [14, 22, 25], "kernel": [14, 17, 19, 25, 26], "disabl": [14, 22, 25], "acpi": [14, 22, 25], "target": [14, 17, 20, 22, 25], "featur": [14, 17, 22, 25], "throw": [14, 22, 25], "interrupt": [14, 22, 25], "interfer": [14, 22, 25], "perform": [14, 17, 19, 22, 25, 26], "enabl": [14, 21, 22, 25], "minimum": [14, 22, 25], "few": [14, 20, 22, 23, 25, 26], "possibl": [14, 22, 25], "exist": [14, 22, 25], "central": [14, 22, 25], "platform": [14, 17, 22, 25], "without": [14, 19, 22, 25], "assur": [14, 22, 25], "harder": [14, 22, 25], "deliv": [14, 22, 25], "violat": [14, 19, 22, 25, 26], "like": [14, 17, 19, 22, 25], "occur": [14, 22, 25], "grow": [14, 22, 25], "evalu": [14, 22, 25], "product": [14, 22, 25], "deploy": [14, 22, 25], "strongli": [14, 22, 25], "advis": [14, 17, 22, 25], "appli": [14, 22, 25], "stock": [14, 22, 25], "ubuntu": [14, 20, 22, 25], "server": [14, 20, 22, 25], "04": [14, 22, 25], "lt": [14, 22, 25], "lico_enable_usb": [14, 22, 25], "kernel_setup": [14, 22, 25], "script": [14, 16, 17, 22, 23, 25], "five": [14, 22, 25], "hour": [14, 22, 25], "complet": [14, 19, 20, 22, 25, 26], "depend": [14, 20, 22, 25], "speed": [14, 18, 22, 25], "processor": [14, 22, 25], "count": [14, 22, 25], "reboot": [14, 22, 25], "finish": [14, 19, 22, 25], "notifi": [14, 22, 25], "keyboard": [14, 22, 25], "after": [14, 17, 19, 22, 25], "point": [14, 22, 25], "p": [14, 22, 25], "ssh": [14, 22, 25], "instead": [14, 19, 20, 22, 25], "via": [14, 17, 18, 22, 23, 25], "degrad": [14, 22, 25], "small": [14, 22, 25], "amount": [14, 22, 25], "still": [14, 22, 25], "fit": [14, 22, 25], "within": [14, 17, 19, 20, 22, 25, 26], "toler": [14, 22, 25, 26], "preclud": [14, 22, 25], "consist": [14, 22, 25, 26], "meet": [14, 22, 25], "1m": [14, 17, 19, 22, 25], "regardless": [14, 22, 25], "alwai": [14, 22, 25], "verifi": [14, 17, 22, 25], "kernel_rt_vers": [14, 22, 25], "feel": [14, 19, 22, 25], "free": [14, 19, 22, 25], "18": [14, 22, 25], "wish": [14, 22, 25], "ubuntu_vers": [14, 22, 25], "4": [14, 18, 20, 22, 25], "16": [14, 22, 25], "rt12": [14, 22, 25], "welcom": [15, 18, 19, 20, 22, 23], "packag": [15, 17, 21, 22], "pypi": 15, "binari": 15, "cut": 16, "releas": 16, "done": 16, "tag": 16, "gitlab": 16, "ci": 16, "release_pypi": 16, "standalon": 16, "create_binari": 16, "portabl": 16, "dist": 16, "experienc": 16, "try": [16, 17, 19], "licorice_onedir": 16, "spec": 16, "highlight": 17, "capabl": 17, "prerequisit": [17, 18], "laid": 17, "similarli": [17, 19], "might": 17, "deploi": 17, "learn": [17, 19], "simpli": [17, 20], "example_nam": 17, "root": 17, "so": [17, 19, 20, 22], "those": 17, "curiou": 17, "increas": [17, 20], "doe": 17, "assist": 17, "simplest": [17, 19, 23], "oper": [17, 19, 26], "pcie": [17, 19], "adapt": [17, 19], "compat": 17, "dev": [17, 19, 22, 23], "parport": [17, 19], "Then": [17, 19, 20, 23], "lp": [17, 19], "group": [17, 19, 20], "usermod": [17, 19], "ag": [17, 19], "effect": [17, 19], "improv": [17, 21], "lower": [17, 19], "oscilloscop": 17, "tap": 17, "9": [17, 18, 19], "squar": 17, "wave": 17, "2m": 17, "period": [17, 26], "3": [17, 18, 20, 23], "3v": 17, "5v": 17, "rail": 17, "jitter_demo": 17, "leverag": 17, "infrastructur": [17, 21], "again": [17, 19, 20], "toggl": [17, 20], "everi": [17, 19, 20], "abov": [17, 19], "demonstr": 17, "numba": 17, "pycc": 17, "bla": 17, "numer": 17, "matmul": 17, "matrix": 17, "4x4": 17, "matric": 17, "sqlite": [17, 19], "bring": [17, 18, 19], "ax": 17, "kernel_setup_usb": 17, "venv": [17, 23], "pip": [17, 20, 22], "long": 17, "least": 17, "logitech": [17, 20], "f310": [17, 20], "gamepad": [17, 20], "sdl": 17, "driven": 17, "sprite": [17, 20], "screen": [17, 19, 20], "window": [17, 20], "appropri": 17, "vis_pygame_setup": 17, "launch": 17, "session": [17, 19], "xinitrc": [17, 20], "startx": [17, 20], "sampl": 17, "home": [17, 23], "repeat": 17, "step": [17, 22], "main": [17, 22], "readm": 17, "licorice_activ": 17, "close": 17, "loop": 17, "cursor": [17, 20], "sever": [17, 26], "prior": 17, "random": [17, 20], "task": [17, 20, 26], "literatur": 17, "displai": [17, 20], "green": [17, 19, 20], "randomli": 17, "place": 17, "acquir": 17, "held": 17, "allot": 17, "relev": 17, "save": [17, 26], "databas": [17, 19], "datalogg": 17, "practic": 18, "quickstart": [18, 21], "hello": 18, "5": 18, "drive": 18, "tutori": [18, 19, 21], "6": [18, 19], "7": [18, 19], "jitter": 18, "audio": 18, "serial": [18, 19], "ethernet": 18, "11": 18, "12": [18, 23], "gpu": 18, "excit": 19, "principl": 19, "convent": [19, 21, 26], "guid": [19, 20, 21], "scratch": 19, "ll": [19, 20], "progress": 19, "pipe": 19, "posix": [19, 21], "compliant": 19, "everyth": [19, 20], "licorice_quickstart": 19, "mkdir": 19, "tell": 19, "anyth": 19, "touch": [19, 20], "1000000": 19, "t": [19, 20], "counter_simpl": 19, "its": 19, "counter_simple_constructor": 19, "counter": [19, 20], "flush": [19, 20], "increment": 19, "interpol": 19, "stdout": 19, "appear": 19, "immedi": 19, "individu": 19, "among": [19, 20], "split": 19, "exactli": 19, "printer": 19, "copi": 19, "cp": 19, "tick_count": 19, "int32": 19, "nest": 19, "info": 19, "next": [19, 20], "remov": [19, 20], "ahead": [19, 20], "three": 19, "tick_counter_constructor": 19, "job": 19, "along": 19, "final": [19, 20], "logic": 19, "track": [19, 20], "u": [19, 20], "entir": [19, 26], "fact": 19, "And": [19, 20], "logger": 19, "disk": 19, "log_sqlit": 19, "save_fil": 19, "todo": 19, "wa": [19, 26], "sqlite3": [19, 22], "data_0000": 19, "db": 19, "select": [19, 22], "far": 19, "ve": [19, 20], "dealt": [19, 26], "aren": 19, "meant": 19, "digit": 19, "pc": 19, "empti": [19, 20], "slot": 19, "2x": 19, "card": 19, "don": [19, 20], "db25": 19, "male": 19, "femal": 19, "cabl": 19, "breakout": 19, "board": 19, "4x": 19, "jumper": 19, "wire": [19, 20], "hand": 19, "hantek": 19, "dso2d10": 19, "doc": 19, "fairli": 19, "inexpens": 19, "persist": 19, "let": 19, "monitor": 19, "plug": 19, "low": 19, "expans": 19, "bracket": 19, "l": 19, "parport0": 19, "parport1": 19, "isn": 19, "easiest": 19, "solut": 19, "unfortun": 19, "unfamiliar": 19, "pci": 19, "watch": 19, "video": 19, "correctli": 19, "connect": [19, 20], "side": 19, "loosen": 19, "screw": 19, "insert": 19, "gnd": 19, "25": 19, "tighten": 19, "pinout": 19, "bnc": 19, "probe": 19, "black": [19, 20], "allig": 19, "clip": [19, 20], "channel": 19, "reset": 19, "restart": 19, "parallel_writ": 19, "parallel_out": 19, "parport_out": 19, "parallel_toggle_constructor": 19, "toggle_switch": 19, "0b00000000": 19, "0b10000000": 19, "0b": 19, "syntax": 19, "bit": 19, "integ": 19, "could": 19, "easili": 19, "0b11111111": 19, "turn": [19, 26], "trace": 19, "jump": 19, "switch": 19, "lot": 19, "comment": 19, "decreas": 19, "10hz": 19, "50000": 19, "50m": 19, "adjust": 19, "ch1": 19, "menu": [19, 22], "horizont": 19, "scale": 19, "sec": 19, "div": 19, "knob": 19, "divis": 19, "topbar": 19, "vertic": 19, "1v": 19, "suffici": 19, "trig": 19, "edg": 19, "ch2": 19, "slope": 19, "rise": 19, "midpoint": 19, "someth": 19, "last": 19, "parallel_read": 19, "parport_in": 19, "parallel_in": 19, "popul": 19, "renam": 19, "parallel_through": 19, "lastli": 19, "licorice_working_dir": 19, "jaw": 19, "ext": 19, "gen": 19, "ground": 19, "red": [19, 20], "There": 19, "room": 19, "press": [19, 20], "scope": 19, "waveform": 19, "000hz": 19, "amplitud": 19, "300v": 19, "offset": [19, 20], "000v": 19, "both": [19, 20, 26], "necessarili": 19, "phase": 19, "other": [19, 22, 23], "better": 19, "align": 19, "sai": 19, "10000": [19, 20], "10m": 19, "1000": 19, "rate": 19, "patch": [19, 26], "caus": 19, "visual": 19, "replic": 19, "want": 19, "bitwis": 19, "NOT": 19, "flip": [19, 20], "paralell_out": 19, "invert": 19, "gotten": 19, "congrat": 19, "intend": 20, "difficulti": 20, "get": [20, 22], "game": 20, "known": 20, "util": 20, "begin": 20, "graphic": 20, "As": 20, "workspac": 20, "xinput": 20, "alter": 20, "gui": 20, "apt": [20, 22, 23], "xinit": 20, "openbox": 20, "lxtermin": 20, "content": 20, "geometri": 20, "1000x1000": 20, "consol": 20, "200": 20, "directinput": 20, "joystick_print": 20, "incom": 20, "click": 20, "axi": 20, "Be": 20, "coupl": 20, "joystick_reader_pars": 20, "tool": [20, 21], "object": 20, "event": 20, "pump": 20, "ax0": 20, "get_axi": 20, "ax1": 20, "get_button": 20, "get_numbutton": 20, "continu": 20, "accordingli": 20, "pnumtick": 20, "ny": 20, "nbutton": 20, "walkthrough": 20, "sdl_videodriv": 20, "subsequ": 20, "sdlvideo_driv": 20, "dummi": 20, "state": 20, "outsid": 20, "pygame_displai": 20, "viz": 20, "vis_pygam": 20, "pygame_display_pars": 20, "pygame_display_destructor": 20, "pygame_display_constructor": 20, "math": 20, "init": [20, 23], "class": 20, "circl": 20, "def": 20, "__init__": 20, "self": 20, "color": 20, "radiu": 20, "po": 20, "imag": 20, "surfac": 20, "convert_alpha": 20, "draw": 20, "rect": 20, "get_rect": 20, "set_color": 20, "get_po": 20, "set_po": 20, "set_siz": 20, "cur_po": 20, "screen_width": 20, "1280": 20, "screen_height": 20, "1024": 20, "set_mod": 20, "pygame_demo": 20, "cursor_track": 20, "circle_s": 20, "30": 20, "r": [20, 21, 22], "theta": 20, "500": 20, "vel_scal": 20, "cir1": 20, "refresh_r": 20, "m": [20, 23], "peek": 20, "eventtyp": 20, "quit": 20, "handle_exit": 20, "vel": 20, "np": 20, "movement": 20, "neurosci": [20, 26], "experi": [20, 26], "pos_cursor": 20, "pos_target": 20, "size_cursor": 20, "size_target": 20, "color_cursor": 20, "color_target": 20, "float": 20, "pinball_task": 20, "state_task": 20, "vector": 20, "suffix": 20, "uint16": 20, "int8": 20, "pinball_task_constructor": 20, "sprite_cursor": 20, "sprite_target": 20, "becaus": 20, "were": 20, "ran": 20, "constant": 20, "task_stat": 20, "hold": 20, "fail": 20, "end": 20, "255": 20, "blue": 20, "white": 20, "light_blu": 20, "150": 20, "counter_hold": 20, "counter_begin": 20, "counter_success": 20, "counter_fail": 20, "counter_end": 20, "counter_dur": 20, "pos_cursor_i": 20, "100": 20, "pos_target_i": 20, "50": 20, "size_cursor_i": 20, "int": 20, "size_target_i": 20, "color_cursor_i": 20, "color_target_i": 20, "is_cursor_on_target": 20, "gen_new_target": 20, "width_max": 20, "height_max": 20, "rand": 20, "param": 20, "time_hold": 20, "time_dur": 20, "400": 20, "time_success": 20, "time_fail": 20, "time_begin": 20, "time_end": 20, "acceptance_window": 20, "cursor_vel_scal": 20, "cursor_on_target": 20, "elif": 20, "entail": 20, "come": 20, "soon": 20, "li": 21, "nux": 21, "co": 21, "modular": 21, "ealtim": 21, "nteract": 21, "omput": 21, "ngine": 21, "prototyp": [21, 26], "hardwar": [21, 26], "translat": 21, "design": 21, "maintain": 21, "flexibl": 21, "librari": 21, "why": 21, "advanc": 21, "debian": 22, "libev": 22, "libsqlite3": 22, "libmsgpack": 22, "libopenbla": 22, "gfortran": 22, "mac": [22, 23], "homebrew": 22, "brew": [22, 23], "openbla": 22, "msgpack": 22, "unabl": 22, "link": 22, "put": 22, "prefix": 22, "latest": 22, "That": 22, "soft": [22, 26], "stricter": 22, "machin": 22, "boot": 22, "unam": 22, "guidanc": 22, "achiev": [22, 26], "firmer": 22, "veri": 22, "describ": 23, "Of": 23, "cours": 23, "method": 23, "prefer": 23, "virtual": 23, "matter": 23, "curl": 23, "bin": 23, "eval": 23, "exec": 23, "download": 23, "yet": 23, "python3": 23, "env": 23, "around": 26, "critic": 26, "longest": 26, "timefram": 26, "hard": 26, "constitut": 26, "error": 26, "crash": 26, "wherea": 26, "paradigm": 26, "variou": 26, "across": 26, "field": 26, "cruis": 26, "thermostat": 26, "pacemak": 26, "born": 26, "neural": 26, "gb": 26, "neuron": 26, "fire": 26, "maximum": 26, "hundr": 26, "hertz": 26, "rigor": 26, "millisecond": 26, "1khz": 26, "suitabl": 26, "box": 26, "standard": 26, "behind": 26, "scene": 26, "preemptibl": 26, "fan": 26, "preempt_rt": 26, "mean": 26, "space": 26, "preced": 26, "bound": 26}, "objects": {"licorice": [[6, 0, 1, "", "compile_model"], [6, 0, 1, "", "export_model"], [6, 0, 1, "", "generate_model"], [6, 0, 1, "", "go"], [6, 0, 1, "", "parse_model"], [6, 0, 1, "", "run_model"]]}, "objtypes": {"0": "py:function"}, "objnames": {"0": ["py", "function", "Python function"]}, "titleterms": {"custom": [0, 22], "driver": [0, 9], "exampl": [0, 7, 17], "debug": 1, "model": [1, 7, 17, 19, 20], "advanc": [2, 22], "usag": [2, 10], "content": [2, 5, 10, 18, 21], "licoric": [3, 5, 6, 15, 17, 19, 20, 21], "cli": 3, "command": 3, "gener": [3, 19, 20], "pars": 3, "compil": 3, "run": [3, 19, 20], "go": 3, "export": 3, "refer": [3, 5, 7], "environ": [4, 14], "variabl": 4, "path": 4, "directori": [4, 8, 17], "api": [5, 6], "python": [6, 23], "yaml": 7, "configur": 7, "config": [7, 19], "signal": [7, 19], "modul": [7, 11, 19, 20], "extern": [7, 19], "structur": [8, 17], "sync": 9, "v": 9, "async": 9, "basic": [10, 22], "write": [11, 19, 20], "process": 11, "common": 11, "properti": 11, "parser": 12, "sourc": 12, "sink": 12, "contribut": 13, "develop": [14, 15], "setup": [14, 19, 20], "guid": [15, 18], "here": 15, "we": 15, "take": 15, "deep": 15, "dive": 15, "codebas": 15, "packag": 16, "pypi": 16, "binari": 16, "jitter": [17, 20], "parallel_toggl": [17, 19], "matrix_multipli": 17, "logger": 17, "joystick": [17, 20], "pygam": [17, 20], "cursor_track": 17, "pinbal": [17, 20], "user": [18, 20], "quickstart": [19, 20], "0": [19, 20], "prerequisit": [19, 20], "1": [19, 22], "simpl": 19, "hello": 19, "world": 19, "creat": 19, "workspac": 19, "specifi": [19, 20], "2": [19, 22], "pass": 19, "updat": 19, "3": 19, "add": [19, 20], "log": 19, "examin": 19, "result": 19, "4": 19, "output": 19, "an": 19, "hardwar": 19, "permiss": 19, "file": 19, "view": 19, "oscilloscop": 19, "squar": 19, "wave": 19, "set": 19, "trigger": 19, "5": [19, 20], "drive": 19, "from": 19, "input": [19, 20], "toggler": 19, "up": 19, "function": 19, "manipul": 19, "conclus": 19, "tutori": 20, "6": 20, "via": 20, "read": 20, "print": 20, "visual": 20, "logic": 20, "modifi": 20, "specif": 20, "regener": 20, "our": 20, "7": 20, "demo": 20, "8": 20, "audio": 20, "line": 20, "out": 20, "9": 20, "serial": 20, "port": 20, "10": 20, "ethernet": 20, "11": 20, "asynchron": 20, "12": 20, "gpu": 20, "document": 21, "instal": [22, 23], "improv": 22, "realtim": [22, 26], "time": 22, "option": 22, "easi": 22, "linux": 22, "lowlat": 22, "kernel": 22, "virtualenv": 23, "pyenv": 23, "conda": 23, "system": 23, "why": 26}, "envversion": {"sphinx.domains.c": 2, "sphinx.domains.changeset": 1, "sphinx.domains.citation": 1, "sphinx.domains.cpp": 8, "sphinx.domains.index": 1, "sphinx.domains.javascript": 2, "sphinx.domains.math": 2, "sphinx.domains.python": 3, "sphinx.domains.rst": 2, "sphinx.domains.std": 2, "sphinx": 57}, "alltitles": {"Custom Drivers": [[0, "custom-drivers"]], "Example": [[0, "example"]], "Debugging Models": [[1, "debugging-models"]], "Advanced Usage": [[2, "advanced-usage"]], "Contents:": [[2, null], [5, null], [10, null], [18, null], [21, null]], "LiCoRICE CLI": [[3, "licorice-cli"]], "Commands": [[3, "commands"]], "Generate": [[3, "generate"]], "Parse": [[3, "parse"]], "Compile": [[3, "compile"]], "Run": [[3, "run"]], "Go": [[3, "go"]], "Export": [[3, "export"]], "Reference": [[3, "reference"]], "Environment Variables": [[4, "environment-variables"]], "Paths": [[4, "paths"]], "Directories": [[4, "directories"]], "LiCoRICE API Reference": [[5, "licorice-api-reference"]], "LiCoRICE Python API": [[6, "licorice-python-api"]], "YAML Configuration Reference": [[7, "yaml-configuration-reference"]], "Models": [[7, "models"]], "Config": [[7, "config"]], "Signals": [[7, "signals"]], "Modules": [[7, "modules"]], "External Signals": [[7, "external-signals"]], "Example Model": [[7, "example-model"]], "Directory Structure": [[8, "directory-structure"]], "Drivers": [[9, "drivers"]], "Sync vs Async": [[9, "sync-vs-async"]], "Basic Usage": [[10, "basic-usage"]], "Writing Module Processes": [[11, "writing-module-processes"]], "Common Properties": [[11, "common-properties"]], "Parsers": [[12, "parsers"]], "Source Parsers": [[12, "source-parsers"]], "Sink Parsers": [[12, "sink-parsers"]], "Contributing": [[13, "contributing"]], "Development Environment Setup": [[14, "development-environment-setup"]], "Developer Guide": [[15, "developer-guide"]], "Here we will take a deep dive into the LiCoRICE codebase:": [[15, null]], "Packaging": [[16, "packaging"]], "PyPI": [[16, "pypi"]], "Binary": [[16, "binary"]], "LiCoRICE Examples": [[17, "licorice-examples"]], "Directory structure": [[17, "directory-structure"]], "Example models": [[17, "example-models"]], "jitter": [[17, "jitter"]], "parallel_toggle": [[17, "parallel-toggle"]], "matrix_multiply": [[17, "matrix-multiply"]], "logger": [[17, "logger"]], "joystick": [[17, "joystick"]], "pygame": [[17, "pygame"]], "cursor_track": [[17, "cursor-track"]], "pinball": [[17, "pinball"]], "User Guide": [[18, "user-guide"]], "LiCoRICE Quickstart": [[19, "licorice-quickstart"]], "0. Prerequisites": [[19, "prerequisites"]], "1. Simple Hello World": [[19, "simple-hello-world"]], "Create a workspace": [[19, "create-a-workspace"]], "Specify the model": [[19, "specify-the-model"], [20, "specify-the-model"]], "Generate modules": [[19, "generate-modules"], [19, "id1"]], "Write modules": [[19, "write-modules"], [19, "id2"]], "Run LiCoRICE": [[19, "run-licorice"], [19, "id3"], [19, "id5"], [19, "id7"], [19, "id9"], [20, "run-licorice"], [20, "id1"], [20, "id3"]], "2. Pass a Signal": [[19, "pass-a-signal"]], "Update model config": [[19, "update-model-config"], [19, "id4"], [19, "id6"], [19, "id8"]], "3. Add Logging": [[19, "add-logging"]], "Examine the results": [[19, "examine-the-results"]], "4. Output an External Signal": [[19, "output-an-external-signal"]], "Prerequisite Hardware": [[19, "prerequisite-hardware"]], "Hardware Setup": [[19, "hardware-setup"]], "Permissions": [[19, "permissions"]], "Add parallel_toggle module files": [[19, "add-parallel-toggle-module-files"]], "View the oscilloscope output as a square wave": [[19, "view-the-oscilloscope-output-as-a-square-wave"]], "Setting a trigger": [[19, "setting-a-trigger"]], "5. Drive Output from an External Input": [[19, "drive-output-from-an-external-input"]], "Update toggler module": [[19, "update-toggler-module"]], "Set up the oscilloscope function generator": [[19, "set-up-the-oscilloscope-function-generator"]], "Oscilloscope view": [[19, "oscilloscope-view"]], "Manipulate the signal": [[19, "manipulate-the-signal"]], "Conclusion": [[19, "conclusion"]], "LiCoRICE Tutorial": [[20, "licorice-tutorial"]], "0-5: Prerequisites (Quickstart)": [[20, "prerequisites-quickstart"]], "6: User Input via Joystick": [[20, "user-input-via-joystick"]], "Setup": [[20, "setup"]], "Read and print joystick input": [[20, "read-and-print-joystick-input"]], "Generate joystick modules": [[20, "generate-joystick-modules"]], "Write joystick modules": [[20, "write-joystick-modules"]], "Visualize the input": [[20, "visualize-the-input"]], "Specify pygame module in the model": [[20, "specify-pygame-module-in-the-model"]], "Generate pygame modules": [[20, "generate-pygame-modules"]], "Write pygame modules": [[20, "write-pygame-modules"], [20, "id2"]], "Add pinball logic": [[20, "add-pinball-logic"]], "Modify module specifications in the model": [[20, "modify-module-specifications-in-the-model"]], "Regenerate our modified modules": [[20, "regenerate-our-modified-modules"]], "7: Jitter demo": [[20, "jitter-demo"]], "8: Audio line in/out": [[20, "audio-line-in-out"]], "9: Serial port": [[20, "serial-port"]], "10: Ethernet": [[20, "ethernet"]], "11 Asynchronous modules": [[20, "asynchronous-modules"]], "12: GPU": [[20, "gpu"]], "LiCoRICE Documentation": [[21, "licorice-documentation"]], "Installation": [[22, "installation"]], "Basic Install": [[22, "basic-install"]], "Improve Realtime Timings": [[22, "improve-realtime-timings"]], "Option 1 (easy): linux-lowlatency": [[22, "option-1-easy-linux-lowlatency"]], "Option 2 (advanced): custom kernel": [[22, "option-2-advanced-custom-kernel"]], "Installing Python and virtualenv": [[23, "installing-python-and-virtualenv"]], "Pyenv": [[23, "pyenv"]], "Conda": [[23, "conda"]], "System Python": [[23, "system-python"]], "Why Realtime?": [[26, "why-realtime"]]}, "indexentries": {"compile_model() (in module licorice)": [[6, "licorice.compile_model"]], "export_model() (in module licorice)": [[6, "licorice.export_model"]], "generate_model() (in module licorice)": [[6, "licorice.generate_model"]], "go() (in module licorice)": [[6, "licorice.go"]], "parse_model() (in module licorice)": [[6, "licorice.parse_model"]], "run_model() (in module licorice)": [[6, "licorice.run_model"]]}})