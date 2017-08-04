import os, shutil
import jinja2
import sys
from toposort import toposort

# some constants
TEMPLATE_DIR='./templates'
GENERATE_DIR='./generate'
MODULE_DIR='./modules'
OUTPUT_DIR='./out'
EXPORT_DIR='./export'

TMP_MODULE_DIR='./.modules'
TMP_OUTPUT_DIR='./.out'

TEMPLATE_MODULE_C='module_c.j2'
TEMPLATE_MODULE_PY='module_py.j2'
TEMPLATE_LOGGER='logger.j2'
TEMPLATE_SINK_PY='sink.pyx.j2'
TEMPLATE_SINK_C='sink.c.j2'
TEMPLATE_SOURCE_PY='source.pyx.j2'
TEMPLATE_SOURCE_C='source.c.j2'
TEMPLATE_MAKEFILE='Makefile.j2'
TEMPLATE_TIMER='timer.j2'
TEMPLATE_CONSTANTS='constants.j2'

G_TEMPLATE_MODULE_CODE_PY='module_code_py.j2'
G_TEMPLATE_SOURCE_PARSER_PY='source_parser_py.j2'
G_TEMPLATE_SINK_PARSER_PY='sink_parser_py.j2'
G_TEMPLATE_CONSTRUCTOR_PY='constructor_py.j2'
G_TEMPLATE_DESTRUCTOR_PY='destructor_py.j2'
G_TEMPLATE_MODULE_CODE_C='module_code_c.j2'
G_TEMPLATE_SOURCE_PARSER_C='source_parser_c.j2'
G_TEMPLATE_SINK_PARSER_C='sink_parser_c.j2'
G_TEMPLATE_CONSTRUCTOR_C='constructor_c.j2'
G_TEMPLATE_DESTRUCTOR_C='destructor_c.j2'

OUTPUT_MAKEFILE='Makefile'
OUTPUT_TIMER='timer.c'
OUTPUT_CONSTANTS='constants.h'

MAX_NUM_CORES = 4

# load, setup, and write template
def do_jinja(template_path, out_path, **data):
  template = jinja2.Template(open(template_path, 'r').read())
  out_f = open(out_path, 'w')
  out_f.write(template.render(data))
  out_f.close()

def generate(config, confirm):
  print "Generating modules...\n"

  if os.path.exists(MODULE_DIR):
    if confirm:
      while True:
        sys.stdout.write("Ok to remove old module directory? ")
        choice = raw_input().lower()
        if choice == 'y':
          break
        elif choice == 'n':
          print "Could not complete generation. Backup old modules if necessary and try again."
          exit()
        else:
          print "Please respond with 'y' or 'n'."
    if os.path.exists(TMP_MODULE_DIR):
      shutil.rmtree(TMP_MODULE_DIR) 
    shutil.move(MODULE_DIR, TMP_MODULE_DIR)
    print "Moved " + MODULE_DIR + " to " + TMP_MODULE_DIR
    shutil.rmtree(MODULE_DIR, ignore_errors=True)
    print "Removed old output directory.\n"

  os.mkdir(MODULE_DIR)

  print "Generated modules:"
  modules = config['modules']
  signals = config['signals']
  external_signals = []
  for signal_name, signal_args in signals.iteritems():
    if signal_args.has_key('args'):
      external_signals.append(signal_name)

  for module_name, module_args in modules.iteritems():
    if all(map(lambda x: x in external_signals, module_args.get('in', []))):
      # source
      print " - " + module_name + " (source)"

      if module_args['language'] == 'python':
        parse_template = G_TEMPLATE_SOURCE_PARSER_PY
        construct_template = G_TEMPLATE_CONSTRUCTOR_PY
        destruct_template = G_TEMPLATE_DESTRUCTOR_PY
        extension = ".py"
      else: 
        parse_template = G_TEMPLATE_SOURCE_PARSER_C
        construct_template = G_TEMPLATE_CONSTRUCTOR_C
        destruct_template = G_TEMPLATE_DESTRUCTOR_C
        extension = ".c"

      # generate source parser template
      if module_args.has_key('parser') and module_args['parser']:
        if module_args['parser'] == True:
          module_args['parser'] = module_name + "_parser"
        print "   - " + module_args['parser']  + " (parser)"
        do_jinja( os.path.join(GENERATE_DIR, parse_template), 
                  os.path.join(MODULE_DIR, module_args['parser'] + extension))

      # generate source constructor template
      if module_args.has_key('constructor') and module_args['constructor']:
        if module_args['constructor'] == True:
          module_args['constructor'] = module_name + "_constructor"
        print "   - " + module_args['constructor']  + " (constructor)"
        do_jinja( os.path.join(GENERATE_DIR, construct_template), 
                  os.path.join(MODULE_DIR, module_args['constructor'] + extension))

      # generate source destructor template
      if module_args.has_key('destructor') and module_args['destructor']:
        if module_args['destructor'] == True:
          module_args['destructor'] = module_name + "_destructor"
        print "   - " + module_args['destructor']  + " (destructor)"
        do_jinja( os.path.join(GENERATE_DIR, destruct_template), 
                  os.path.join(MODULE_DIR, module_args['destructor'] + extension))

    elif all(map(lambda x: x in external_signals, module_args['out'])): 
      # sink
      print " - " + module_name + " (sink)"

      if module_args['language'] == 'python':
        parse_template = G_TEMPLATE_SOURCE_PARSER_PY
        construct_template = G_TEMPLATE_CONSTRUCTOR_PY
        destruct_template = G_TEMPLATE_DESTRUCTOR_PY
        extension = ".py"
      else: 
        parse_template = G_TEMPLATE_SOURCE_PARSER_C
        construct_template = G_TEMPLATE_CONSTRUCTOR_C
        destruct_template = G_TEMPLATE_DESTRUCTOR_C
        extension = ".c"

      if module_args.has_key('parser') and module_args['parser']:
        if module_args['parser'] == True:
          module_args['parser'] = module_name + "_parser"
        print "   - " + module_args['parser']  + " (parser)"
        do_jinja( os.path.join(GENERATE_DIR, parse_template), 
                  os.path.join(MODULE_DIR, module_args['parser'] + extension))

      if module_args.has_key('constructor') and module_args['constructor']:
        if module_args['constructor'] == True:
          module_args['constructor'] = module_name + "_constructor"
        print "   - " + module_args['constructor']  + " (constructor)"
        do_jinja( os.path.join(GENERATE_DIR, construct_template), 
                  os.path.join(MODULE_DIR, module_args['constructor'] + extension))

      if module_args.has_key('destructor') and module_args['destructor']:
        if module_args['destructor'] == True:
          module_args['destructor'] = module_name + "_destructor"
        print "   - " + module_args['destructor']  + " (destructor)"
        do_jinja( os.path.join(GENERATE_DIR, destruct_template), 
                  os.path.join(MODULE_DIR, module_args['destructor'] + extension))

    else: 
      # module
      print " - " + module_name
      do_jinja( os.path.join(GENERATE_DIR, G_TEMPLATE_MODULE_CODE_PY),
                os.path.join(MODULE_DIR, module_name + '.py'),
                name=module_name, 
                verbose_comments=config['config']['verbose_comments'],
                in_sig=module_args.get('in', []), 
                out_sig=module_args['out'] )

      if module_args.has_key('constructor') and module_args['constructor']:
        if module_args['constructor'] == True:
          module_args['constructor'] = module_name + "_constructor"
        print "   - " + module_args['constructor']  + " (constructor)"
        do_jinja( os.path.join(GENERATE_DIR, construct_template), 
                  os.path.join(MODULE_DIR, module_args['constructor'] + extension))


      if module_args.has_key('destructor') and module_args['destructor']:
        if module_args['destructor'] == True:
          module_args['destructor'] = module_name + "_destructor"
        print "   - " + module_args['destructor']  + " (destructor)"
        do_jinja( os.path.join(GENERATE_DIR, destruct_template), 
                  os.path.join(MODULE_DIR, module_args['destructor'] + extension))


def parse(config, confirm):
  print "Parsing"
  # load yaml config
  signals = config['signals']
  sigkeys = set(signals.keys())
  modules = config['modules']

  # set up output directory
  if os.path.exists(OUTPUT_DIR):
    if confirm:
      while True:
        sys.stdout.write("Ok to remove old output directory? ")
        choice = raw_input().lower()
        if choice == 'y':
          break
        elif choice == 'n':
          print "Could not complete parsing. Backup old output directory if necessary and try again."
          exit()
        else:
          print "Please respond with 'y' or 'n'."
      print 
    if os.path.exists(TMP_OUTPUT_DIR):
      shutil.rmtree(TMP_OUTPUT_DIR) 
    shutil.move(OUTPUT_DIR, TMP_OUTPUT_DIR)
    print "Moved " + OUTPUT_DIR + " to " + TMP_OUTPUT_DIR
    shutil.rmtree(OUTPUT_DIR, ignore_errors=True)
    print "Removing old output directory.\n"

  shutil.copytree(TEMPLATE_DIR, OUTPUT_DIR, ignore=shutil.ignore_patterns(('*.j2')))
  external_signals = []
  internal_signals = []
  for signal_name, signal_args in signals.iteritems():
    if signal_args.has_key('args'):
      external_signals.append(signal_name)
    else: 
      internal_signals.append(signal_name)

  # process modules
  sem_location = 0
  sem_dict = {}
  num_sem_sigs = 0
  logged_signals = {}

  module_names = []
  source_names = []
  sink_names = []
  source_outputs = {}
  dependency_graph = {}
  independent_modules = []
  in_signals = {}
  out_signals = {}
  line_source_exists = 0
  print internal_signals
  for module_name, module_args in modules.iteritems():
    if all(map(lambda x: x in external_signals, module_args['in'])):
      source_names.append(module_name)
      for sig in module_args['out']:
        source_outputs[sig] = 0
      for sig in module_args.get('in', []):
        assert signals[sig]['args'].has_key('type')
        in_signals[sig] = signals[sig]['args']['type']
    elif all(map(lambda x: x in external_signals, module_args['out'])):
      sink_names.append(module_name)
      for sig in module_args['out']:
        assert signals[sig]['args'].has_key('type')
        out_signals[sig] = signals[sig]['args']['type']
    else:
      module_names.append(module_name)

    # create semaphore signal mapping w/ format {'sig_name': ptr_offset}
    for sig_name in module_args.get('in', []):
      if not sem_dict.has_key(sig_name):
        sem_dict[sig_name] = sem_location
        sem_location += 1
    num_sem_sigs = len(sem_dict)

  # process input signals
  print "Inputs: "
  for sig_name, sig_type in in_signals.iteritems():
    print " - " + sig_name + ": " + sig_type 
  print "Outputs: "
  for sig_name, sig_type in out_signals.iteritems():
    print " - " + sig_name + ": " + sig_type 

  all_names = source_names + sink_names + module_names
  print all_names
  assert (len(all_names) == len(set(all_names)))

  print "Modules: "

  for name in all_names:
      # get module info
      module_args = modules[name]
      module_language = module_args['language'] # language must be specified

      # parse source
      if name in source_names:
        print " - " + name + " (source)"

        if module_language == 'python':
          template = TEMPLATE_SOURCE_PY
          in_extension = '.py'
          out_extension = '.pyx'
        else:
          template = TEMPLATE_SOURCE_C
          in_extension = '.c'
          out_extension = '.c'

        so_in_sig = { x: signals[x] for x in (sigkeys & set(module_args['in'])) }
        assert len(so_in_sig) == 1
        assert len(module_args['in']) == 1
        so_in_sig = so_in_sig[so_in_sig.keys()[0]]
        out_signals = {x: signals[x] for x in (sigkeys & set(module_args['out']))}
        if (not module_args.has_key('parser') or not module_args['parser']):
          assert len(out_signals) == 1
        if so_in_sig['args']['type'] == 'line':
          line_source_exists = 1
          so_in_sig['schema'] = {}
          so_in_sig['schema']['data'] = {}
          so_in_sig['schema']['data']['dtype'] = 'uint16'
        default_params = None
        if so_in_sig['args']['type'] == 'default':
          default_params = so_in_sig['schema']['default']
          print default_params

        parser_code = ""
        if module_args.has_key('parser') and module_args['parser']:
          if module_args['parser'] == True:
            module_args['parser'] = name + "_parser"
          with open(os.path.join(MODULE_DIR, module_args['parser'] + in_extension), 'r') as f:
            parser_code = f.read()

        construct_code = ""
        if module_args.has_key('constructor') and module_args['constructor']:
          if module_args['constructor'] == True:
            module_args['constructor'] = name + "_constructor"
          with open(os.path.join(MODULE_DIR, module_args['constructor'] + in_extension), 'r') as f:
            construct_code = f.read()

        destruct_code = ""
        if module_args.has_key('destructor') and module_args['destructor']:
          if module_args['destructor'] == True:
            module_args['destructor'] = name + "_destructor"
          with open(os.path.join(MODULE_DIR, module_args['destructor'] + in_extension), 'r') as f:
            destruct_code = f.read()
            destruct_code = destruct_code.replace("\n", "\n  ")

        do_jinja( os.path.join(TEMPLATE_DIR, template), 
                  os.path.join(OUTPUT_DIR, name + out_extension),
                  name=name, 
                  config=config,
                  parser_code=parser_code,
                  construct_code=construct_code,
                  destruct_code=destruct_code, 
                  signals=signals, 
                  out_signals=out_signals,
                  max_buf_size=3750, # TODO, don't hardcode this
                  in_signal=so_in_sig,
                  in_sig_name=module_args['in'][0],
                  default_params=default_params
                )
      
      # parse sink
      elif name in sink_names:
        print " - " + name + " (sink)"

        if module_language == 'python':
          template = TEMPLATE_SINK_PY
          in_extension = '.py'
          out_extension = '.pyx'
        else:
          template = TEMPLATE_SINK_C
          in_extension = '.c'
          out_extension = '.c'

        module_depends_on = []
        source_depends_on = []
        default_sig_name = ''
        default_params = None
        for in_sig in module_args['in']:
          if (in_sig in external_signals) and (signals[in_sig]['args']['type'] == 'default'):
            default_sig_name = in_sig
            default_params = signals[in_sig]['schema']['default']
          elif in_sig in source_outputs.keys():
            #store the signal name in 0 and location of sem in 1
            source_outputs[in_sig] += 1
            source_depends_on.append((in_sig, sem_dict[in_sig]))
          else:
            module_depends_on.append((in_sig, sem_dict[in_sig]))  
        if (name == 'logger'): # TODO make this more generic
          logged_signals = { sig_name: signals[sig_name] for sig_name in module_args.get('in', []) }
        si_out_sig = {x: signals[x] for x in (sigkeys & set(module_args['out']))}
        assert len(si_out_sig) == 1
        si_out_sig = si_out_sig[si_out_sig.keys()[0]]
        in_signals = {x: signals[x] for x in (sigkeys & set(module_args.get('in', [])))}
        if (not module_args.has_key('parser') or not module_args['parser']):
          assert len(in_signals) == 1

        parser_code = ""
        if module_args.has_key('parser') and module_args['parser']:
          if module_args['parser'] == True:
            module_args['parser'] = name + "_parser"
          with open(os.path.join(MODULE_DIR, module_args['parser'] + in_extension), 'r') as f:
            construct_code = f.read()

        construct_code = ""
        if module_args.has_key('constructor') and module_args['constructor']:
          if module_args['constructor'] == True:
            module_args['constructor'] = name + "_constructor"
          with open(os.path.join(MODULE_DIR, module_args['constructor'] + in_extension), 'r') as f:
            construct_code = f.read()

        destruct_code = ""
        if module_args.has_key('destructor') and module_args['destructor']:
          if module_args['destructor'] == True:
            module_args['destructor'] = name + "_destructor"
          with open(os.path.join(MODULE_DIR, module_args['destructor'] + in_extension), 'r') as f:
            destruct_code = f.read()
            destruct_code = destruct_code.replace("\n", "\n  ")

        do_jinja( os.path.join(TEMPLATE_DIR, template),
                  os.path.join(OUTPUT_DIR, name + out_extension),
                  name=name, 
                  config=config, 
                  parser_code=parser_code,
                  construct_code=construct_code,
                  destruct_code=destruct_code, 
                  num_sigs=num_sem_sigs,
                  s_dep_on=source_depends_on,
                  m_dep_on=module_depends_on,
                  logged_signals=logged_signals,
                  num_logged_signals=len(logged_signals),
                  in_signals=in_signals,
                  out_signal=si_out_sig,
                  default_sig_name=default_sig_name,
                  default_params=default_params
                )

      # parse module type
      else:
        if module_language == 'python':
          print " - " + name + " (py)"
          template = TEMPLATE_MODULE_PY
          in_extension = '.py'
          out_extension = '.pyx'
        else:
          raise NotImplementedError()
          print " - " + name + " (c)"
          template = TEMPLATE_MODULE_C
          in_extension = '.c'
          out_extension = '.c'

        # prepare module parameters
        dependencies = {}
        for out_sig in module_args['out']:
          for tmp_name in all_names:
            mod = modules[tmp_name]
            for in_sig in mod['in']:
              if (in_sig == out_sig):
                child_index = all_names.index(tmp_name)
                parent_index = all_names.index(name)
                if dependencies.has_key(in_sig):
                  dependencies[in_sig] += 1
                else:
                  dependencies[in_sig] = 1
                if all_names[child_index] not in sink_names: # take this out to include sinks in dependency graph
                  dg_cidx = module_names.index(all_names[child_index])
                  dg_pidx = module_names.index(name)
                else:
                  independent_modules.append(module_names.index(name))
                  continue
                if dependency_graph.has_key(child_index):
                  dependency_graph[dg_cidx] = dependency_graph[dg_cidx].union({dg_pidx})
                else: 
                  dependency_graph[dg_cidx] = {dg_pidx}
        for dependency in dependencies:
          #store num dependencies in 0 and location of sem in 1
          dependencies[dependency] = (dependencies[dependency], sem_dict[dependency])

        depends_on = []
        default_sig_name = ''
        default_params = None
        for in_sig in module_args['in']:
          if (in_sig in external_signals) and (signals[in_sig]['args']['type'] == 'default'):
            default_sig_name = in_sig
            default_params = signals[in_sig]['schema']['default']
          if in_sig in source_outputs.keys():
            source_outputs[in_sig] += 1
          #store the signal name in 0 and location of sem in 1
          depends_on.append((in_sig, sem_dict[in_sig]))

        user_code = ""
        with open(os.path.join(MODULE_DIR, name + in_extension), 'r') as f:
          user_code = f.read()
          if module_language == 'python':
            user_code = user_code.replace("def ", "cpdef ")

        construct_code = ""
        if module_args.has_key('constructor') and module_args['constructor']:
          if module_args['constructor'] == True:
            module_args['constructor'] = name + "_constructor"
          with open(os.path.join(MODULE_DIR, module_args['constructor'] + in_extension), 'r') as f:
            construct_code = f.read()

        destruct_code = ""
        if module_args.has_key('destructor') and module_args['destructor']:
          if module_args['destructor'] == True:
            module_args['destructor'] = name + "_destructor"
          with open(os.path.join(MODULE_DIR, module_args['destructor'] + in_extension), 'r') as f:
            destruct_code = f.read()
            destruct_code = destruct_code.replace("\n", "\n  ")
            
        do_jinja( os.path.join(TEMPLATE_DIR, template),
                  os.path.join(OUTPUT_DIR, name + out_extension),
                  name=name, 
                  args=module_args,
                  config=config, 
                  user_code=user_code,
                  construct_code=construct_code,
                  destruct_code=destruct_code,
                  dependencies=dependencies, 
                  depends_on=depends_on,
                  out_signals={ x: signals[x] for x in (sigkeys & set(module_args['out'])) },
                  in_signals={ x: signals[x] for x in (sigkeys & set(module_args['in'])) },
                  num_sigs=num_sem_sigs,
                  default_sig_name=default_sig_name,
                  default_params=default_params
                )

  # parse Makefile
  do_jinja( os.path.join(TEMPLATE_DIR, TEMPLATE_MAKEFILE),
            os.path.join(OUTPUT_DIR, OUTPUT_MAKEFILE),
            child_names=module_names,
            logger_needed=(len(logged_signals)!=0),
            source_names=source_names,
            sink_names=sink_names,
            source_types=map(lambda x: modules[x]['language'], source_names)
          )

  # parse timer parent
  topo_children = map(list, list(toposort(dependency_graph)))
  if len(topo_children) == 0:
    topo_children.append(independent_modules)
  else:
    topo_children[0] += independent_modules
  print topo_children
  print module_names
  topo_lens = map(len, topo_children) # TODO, maybe give warning if too many children on one core? Replaces MAX_NUM_ROUNDS assertion
  num_cores = 1 if len(topo_lens) == 0 else max(topo_lens)
  num_children = len(module_names)
  assert(num_cores < MAX_NUM_CORES)
  source_sems = map(lambda x: [sem_dict[x], source_outputs[x]] , source_outputs.keys())
  parport_tick_addr = config['config']['parport_tick_addr'] if config['config'].has_key('parport_tick_addr') else None
  do_jinja( os.path.join(TEMPLATE_DIR, TEMPLATE_TIMER), 
            os.path.join(OUTPUT_DIR, OUTPUT_TIMER),
            config = config,
            topo_order=topo_children,
            topo_lens=topo_lens,
            topo_height=len(topo_children),
            child_names=module_names, 
            num_cores=num_cores,
            num_children=num_children,
            source_names=source_names,
            num_sources=len(source_names),
            sink_names=sink_names,
            num_sinks=len(sink_names),
            num_sigs=num_sem_sigs,
            source_sems=source_sems,
            internal_signals={ x: signals[x] for x in (sigkeys & set(internal_signals)) },
            parport_tick_addr=parport_tick_addr
          )

  # parse constants.h
  do_jinja( os.path.join(TEMPLATE_DIR, TEMPLATE_CONSTANTS),
            os.path.join(OUTPUT_DIR, OUTPUT_CONSTANTS),
            num_children=num_children,
            line=line_source_exists
          )

  print

def export(confirm):
  os.mkdir(EXPORT_DIR)
  if os.path.exists(MODULE_DIR):
      shutil.copytree(MODULE_DIR, EXPORT_DIR + "/modules")
  if os.path.exists(OUTPUT_DIR):
    shutil.copytree(OUTPUT_DIR, EXPORT_DIR + "/out")
