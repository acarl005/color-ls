#  0000000   0000000   000       0000000   00000000           000       0000000
# 000       000   000  000      000   000  000   000          000      000     
# 000       000   000  000      000   000  0000000    000000  000      0000000 
# 000       000   000  000      000   000  000   000          000           000
#  0000000   0000000   0000000   0000000   000   000          0000000  0000000 

ansi   = require 'ansi-256-colors'
fs     = require 'fs'
path   = require 'path'
util   = require 'util'
_s     = require 'underscore.string'
_      = require 'lodash'
moment = require 'moment'
log    = console.log

# 00000000   00000000    0000000   00000000
# 000   000  000   000  000   000  000     
# 00000000   0000000    000   000  000000  
# 000        000   000  000   000  000     
# 000        000   000   0000000   000     

start = 0
token = {}

since = (t) ->
  diff = process.hrtime token[t]
  diff[0] * 1000 + diff[1] / 1000000
  
prof = () -> 
    if arguments.length == 2
        cmd = arguments[0]
        t = arguments[1]
    else if arguments.length == 1
        t = arguments[0]
        cmd = 'start' 

    start = process.hrtime()
    if cmd == 'start'
        token[t] = start
    else if cmd == 'end'
        since(t)
        
prof 'start', 'ls'

# colors
bold   = '\x1b[1m'
reset  = ansi.reset
fg     = ansi.fg.getRgb
BG     = ansi.bg.getRgb
fgc    = (i) -> ansi.fg.codes[i]
fw     = (i) -> ansi.fg.grayscale[i]
BW     = (i) -> ansi.bg.grayscale[i]

stats = # counters for (hidden) dirs/files
    num_dirs:       0
    num_files:      0
    hidden_dirs:    0
    hidden_files:   0
    maxOwnerLength: 0
    maxGroupLength: 0
    brokenLinks:    []

#  0000000   00000000    0000000    0000000
# 000   000  000   000  000        000     
# 000000000  0000000    000  0000  0000000 
# 000   000  000   000  000   000       000
# 000   000  000   000   0000000   0000000 

args = require('karg') """
color-ls
    paths         . ? the file(s) and/or folder(s) to display . **
    bytes         . ? include size                    . = false 
    mdate         . ? include modification date       . = false              
    owner         . ? include owner and group         . = false            
    rights        . ? include rights                  . = false   
    long          . ? include size, date, owner, rights . = false          
    all           . ? show dot files                  . = false
    dirs          . ? show only dirs                  . = false   
    files         . ? show only files                 . = false    
    size          . ? sort by size                    . = false 
    time          . ? sort by time                    . = false 
    kind          . ? sort by kind                    . = false 
    pretty        . ? pretty size and date            . = true
    stats         . ? show statistics                 . = false . - i
    icons         . ? show icons before folders       . = false . - I
    recurse       . ? recurse into subdirs            . = false . - R
    find          . ? filter with a regexp                      . - F
    alphabetical  . ! don't group dirs before files   . = false . - A
    
version      #{require("#{__dirname}/../package.json").version}    
"""

if args.size
    args.files = true

if args.long
    args.bytes = true
    args.mdate = true
    args.owner = true
    args.rights = true

args.paths = ['.'] unless args.paths?.length > 0

#  0000000   0000000   000       0000000   00000000    0000000
# 000       000   000  000      000   000  000   000  000     
# 000       000   000  000      000   000  0000000    0000000 
# 000       000   000  000      000   000  000   000       000
#  0000000   0000000   0000000   0000000   000   000  0000000 

colors = 
    'coffee':   [ bold+fgc(136),  fgc(130) ] 
    'js':       [ bold+fg(4,4,0), fg(2,2,0) ] 
    'json':     [ bold+fg(4,4,0), fg(2,2,0) ] 
    'cson':     [ bold+fgc(136),  fgc(130) ] 
    'jsx':      [ bold+fgc(14),   fgc(6) ]
    'plist':    [ bold+fg(4,0,4), fg(2,0,2) ] 
    'sh':       [ bold+fg(4,0,4), fg(2,0,2) ] 
    'bash':     [ bold+fg(4,0,4), fg(2,0,2) ] 
    'cpp':      [ bold+fg(4,0,4), fg(2,0,2) ] 
    'h':        [ bold+fg(4,0,4), fg(2,0,2) ] 
    'py':       [ bold+fg(0,3,0), fg(0,1,0) ]
    'pyc':      [      fw(8),     fw(5) ]
    'rb':       [ bold+fg(5,1,0), fg(3,0,0) ] 
    'log':      [      fw(8),     fw(5) ]
    'swp':      [      fw(8),     fw(5) ]
    'md':       [      fgc(87),   fgc(73) ]
    'markdown': [      fgc(87),   fgc(73) ]
    'html':     [      fgc(87),   fgc(73) ]
    'css':      [      fgc(219),  fgc(207) ]
    'tar':      [      fg(5,0,0), fg(3,0,0) ] 
    'gz':       [      fg(5,0,0), fg(3,0,0) ] 
    'zip':      [      fg(5,0,0), fg(3,0,0) ] 
    #
    '_default': [      fw(23),    fw(12) ]
    '_dir':     [ bold+BG(0,0,2)+fw(23), fg(1,1,5), fg(2,2,5) ]
    '_.dir':    [ bold+BG(0,0,1)+fw(23), bold+BG(0,0,1)+fg(1,1,5), bold+BG(0,0,1)+fg(2,2,5) ]
    '_link':    { 'arrow': fg(1,0,1), 'path': fg(4,0,4), 'broken': BG(5,0,0)+fg(5,5,0) }
    '_arrow':     fw(1)
    '_header':  [ bold+BW(2)+fg(3,2,0),  fw(4), bold+BW(2)+fg(5,5,0) ]  
    '_media':   [      fgc(141),  fgc(54) ] 
    #
    '_size':    { b: fgc(20), kB: fgc(33), MB: fgc(81), GB: fgc(123) } 
    '_users':   { root:  fg(5,0,2), default: fg(0,3,3) }
    '_groups':  { wheel: fg(3,0,0), staff: fg(0,2,0), admin: fg(2,2,0), default: fg(2,0,2) }
    '_error':   [ bold+BG(5,0,0)+fg(5,5,0), bold+BG(5,0,0)+fg(5,5,5) ]

mediaTypes = new Set ['png', 'gif', 'jpg', 'jpeg', 'ico', 'svg', 'webp', 'tiff', 'pxm', 'mp3', 'm4a', 'wav', 'webm', 'avi', 'wmv']

try
    username = require('userid').username(process.getuid())
    colors['_users'][username] = fg(0,4,0)
catch
    username = ""
        
# 00000000   00000000   000  000   000  000000000
# 000   000  000   000  000  0000  000     000   
# 00000000   0000000    000  000 0 000     000   
# 000        000   000  000  000  0000     000   
# 000        000   000  000  000   000     000   
    
log_error = () -> 
    log " " + colors['_error'][0] + " " + bold + arguments[0] + (arguments.length > 1 and (colors['_error'][1] + [].slice.call(arguments).slice(1).join(' ')) or '') + " " + reset    
    
linkString = (file) ->
    reset + colors['_link']['arrow'] + " ► " + colors['_link'][(file in stats.brokenLinks) and 'broken' or 'path'] + fs.readlinkSync(file)

nameString = (name, ext) ->
    key = if mediaTypes.has(ext) then "_media" else ext
    " " + colors[colors[key]? and key or '_default'][0] + name + reset

extString = (ext) ->
    key = if mediaTypes.has(ext) then "_media" else ext
    colors[colors[key]? and key or '_default'][1] + '.' + ext + reset

dirString = (name, ext) -> 
    c = name and '_dir' or '_.dir'
    name = '📂 ' + name if args.icons
    colors[c][0] + (name and (" " + name) or "") + (if ext then colors[c][1] + '.' + colors[c][2] + ext else "") + " "
        
sizeString = (stat) -> 
    sizes = colors['_size']
    if stat.size < 1000
        if args.pretty
            sizes['b'] + _s.lpad(stat.size, 7) + " B "
        else
            sizes['b'] + _s.lpad(stat.size, 10) + " "
    else if stat.size < 1000000
        if args.pretty 
            sizes['kB'] + _s.lpad((stat.size / 1000).toFixed(0), 7) + "kB "
        else
            sizes['kB'] + _s.lpad(stat.size, 10) + " "
    else if stat.size < 1000000000
        if args.pretty 
            sizes['MB'] + _s.lpad((stat.size / 1000000).toFixed(1), 7) + "MB "
        else
            sizes['MB'] + _s.lpad(stat.size, 10) + " "
    else
        if args.pretty
            sizes['GB'] + _s.lpad((stat.size / 1000000000).toFixed(1), 7) + "GB "
        else
            sizes['GB'] + _s.lpad(stat.size, 10) + " "
    
timeString = (stat) -> 
    t = moment(stat.mtime) 
    fw(20) + (if args.pretty then _s.lpad(t.format("D"),2) else t.format("DD")) + fw(7) + '.' + 
    (if args.pretty then fw(15) + t.format("MMM") + fw(7)+"'" else fw(15) + t.format("MM") + fw(7)+"'") +
    fw(10) + t.format("YY") + " " +
    fw(20) + t.format("HH") + col = fw(7)+':' + 
    fw(15) + t.format("mm") + col = fw(7)+':' +
    fw(10) + t.format("ss") + " "
    
ownerName = (stat) -> 
    try
        require('userid').username(stat.uid)
    catch
        stat.uid        
    
groupName = (stat) ->
    try
        require('userid').groupname(stat.gid)
    catch
        stat.gid    
    
ownerString = (stat, ownerColor, groupColor) ->
    own = ownerName(stat)
    grp = groupName(stat)
    ownerColor + _s.rpad(own, stats.maxOwnerLength) + " " + groupColor + _s.rpad(grp, stats.maxGroupLength)
     
rwxString = (stat, i, color) ->
    mode = (stat.mode >> (i * 3))
    bold + color
    ((mode & 0b100) and 'r' or '-') + 
    ((mode & 0b010) and 'w' or '-') +
    ((mode & 0b001) and 'x' or '-')
    
rightsString = (stat, ownerColor, groupColor) ->
    user = rwxString(stat, 2,) + " "
    group = rwxString(stat, 1,) + " "
    other = rwxString(stat, 0) + " "
    BW(2) + " " + ownerColor + user + groupColor +  group + fw(15) + other + reset
     
#  0000000   0000000   00000000   000000000
# 000       000   000  000   000     000   
# 0000000   000   000  0000000       000   
#      000  000   000  000   000     000   
# 0000000    0000000   000   000     000   
    
sort = (list, stats, exts=[]) ->
    l = _.zip list, stats, [0...list.length], (exts.length > 0 and exts or [0...list.length])
    if args.kind
        if exts == [] then return list
        l.sort((a,b) -> 
            if a[3] > b[3] then return 1 
            if a[3] < b[3] then return -1
            if args.time
                m = moment(a[1].mtime)
                if m.isAfter(b[1].mtime) then return 1
                if m.isBefore(b[1].mtime) then return -1
            if args.size
                if a[1].size > b[1].size then return 1
                if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    else if args.time
        l.sort((a,b) -> 
            m = moment(a[1].mtime)
            if m.isAfter(b[1].mtime) then return 1
            if m.isBefore(b[1].mtime) then return -1
            if args.size
                if a[1].size > b[1].size then return 1
                if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    else if args.size
        l.sort((a,b) -> 
            if a[1].size > b[1].size then return 1
            if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    _.unzip(l)[0]
     
# 00000000  000  000      00000000   0000000
# 000       000  000      000       000     
# 000000    000  000      0000000   0000000 
# 000       000  000      000            000
# 000       000  0000000  00000000  0000000 
        
listFiles = (p, files) ->
    alph = [] if args.alphabetical
    dirs = [] # visible dirs
    fils = [] # visible files
    dsts = [] # dir stats
    fsts = [] # file stats
    exts = [] # file extensions
    
    if args.owner
        files.forEach (rp) ->     
            if rp[0] == '/'
                file = path.resolve(rp)
            else
                file  = path.join(p, rp)
            try
                stat = fs.lstatSync(file)
                ol = ownerName(stat).length
                gl = groupName(stat).length
                if ol > stats.maxOwnerLength
                    stats.maxOwnerLength = ol
                if gl > stats.maxGroupLength
                    stats.maxGroupLength = gl
            catch
                return
                
    files.forEach (rp) -> 
        if rp[0] == '/'
            file  = path.resolve rp
        else
            file  = path.join p, rp
        try    
            lstat = fs.lstatSync file
            link  = lstat.isSymbolicLink()
            stat  = link and fs.statSync(file) or lstat
        catch
            if link
                stat = lstat
                stats.brokenLinks.push file
            else
                log_error 'can\'t read file:', file, link
                return
            
        ext  = path.extname(file).substr(1)
        name = path.basename(file, path.extname file)
        if name[0] == '.'
            ext = name.substr(1) + path.extname file
            name = ''
        if name.length or args.all
            own = ownerName(stat)
            grp = groupName(stat)
            ownerColor = colors['_users'][own]
            ownerColor = colors['_users']['default'] unless ownerColor
            groupColor = colors['_groups'][grp]
            groupColor = colors['_groups']['default'] unless groupColor
            s = "" 
            if args.rights
                s += rightsString stat, ownerColor, groupColor
                s += " "                
            if args.owner
                s += ownerString stat, ownerColor, groupColor
                s += " "
            if args.bytes
                s += sizeString stat
            if args.mdate
                s += timeString stat
            if stat.isDirectory()
                if not args.files
                    s += dirString name, ext
                    if link 
                        s += linkString file
                    dirs.push s+reset
                    alph.push s+reset if args.alphabetical
                    dsts.push stat
                    stats.num_dirs += 1
                else
                    stats.hidden_dirs += 1
            else # if path is file
                if not args.dirs
                    s += nameString name, ext
                    if ext 
                        s += extString ext
                    if link 
                        s += linkString file
                    fils.push s+reset
                    alph.push s+reset if args.alphabetical
                    fsts.push stat
                    exts.push ext
                    stats.num_files += 1
                else 
                    stats.hidden_files += 1
        else
            if stat.isFile()
                stats.hidden_files += 1
            else if stat.isDirectory()
                stats.hidden_dirs += 1
        
    if args.size or args.kind or args.time
        if dirs.length and not args.files
            dirs = sort dirs, dsts
        if fils.length
            fils = sort fils, fsts, exts
    
    if args.alphabetical
        log p for p in alph
    else
        log d for d in dirs
        log f for f in fils
                
# 0000000    000  00000000 
# 000   000  000  000   000
# 000   000  000  0000000  
# 000   000  000  000   000
# 0000000    000  000   000
                
listDir = (p) ->
    ps = p
        
    try
        files = fs.readdirSync(p)
        
    catch error
        msg = error.message
        msg = "permission denied" if _s.startsWith(msg, "EACCES")
        log_error msg
        
    if args.find
        files = files.filter (f) -> 
            f if RegExp(args.find).test f
    if args.find and not files.length
        true
    else if args.paths.length == 1 and args.paths[0] == '.' and not args.recurse
        log reset
    else
        s = colors['_arrow'] + "►" + colors['_header'][0] + " "
        ps = path.resolve(ps) if ps[0] != '~'
        if _s.startsWith(ps, process.env.PWD)
            ps = "./" + ps.substr(process.env.PWD.length)
        else if _s.startsWith(p, process.env.HOME)
            ps = "~" + p.substr(process.env.HOME.length)
            
        if ps == '/'
            s += '/'
        else
            sp = ps.split('/')
            s += colors['_header'][0] + sp.shift()
            while sp.length
                pn = sp.shift()
                if pn 
                    s += colors['_header'][1] + '/'
                    s += colors['_header'][sp.length == 0 and 2 or 0] + pn     
        log reset
        log s + " " + reset
        log reset
    
    if files.length  
        listFiles(p, files)
    
    if args.recurse
        for pr in fs.readdirSync(p).filter( (f) -> fs.lstatSync(path.join(p,f)).isDirectory() )
            listDir(path.resolve(path.join(p, pr)))
    
# 00     00   0000000   000  000   000
# 000   000  000   000  000  0000  000
# 000000000  000000000  000  000 0 000
# 000 0 000  000   000  000  000  0000
# 000   000  000   000  000  000   000
                
pathstats = args.paths.map (f) ->
    try 
         [f, fs.statSync(f)]
    catch error
        log_error 'no such file: ', f
        []
                
filestats = pathstats.filter( (f) -> f.length and not f[1].isDirectory() )                
if filestats.length > 0
    log reset
    listFiles process.cwd(), filestats.map( (s) -> s[0] )
    
for p in pathstats.filter( (f) -> f.length and f[1].isDirectory() )
    listDir p[0]
    
if args.stats
    sprintf = require("sprintf-js").sprintf
    log BW(1) + " " +
    fw(15) + stats.num_dirs + (stats.hidden_dirs and fw(10) + "+" + fw(12) + (stats.hidden_dirs) or "") + fw(10) + " dirs " + 
    fw(15) + stats.num_files + (stats.hidden_files and fw(10) + "+" + fw(12) + (stats.hidden_files) or "") + fw(10) + " files " + 
    fw(15) + sprintf("%2.1f", prof('end', 'ls')) + fw(10) + " ms" + " " +
    reset   
