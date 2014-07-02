express = require 'express'
fs      = require 'fs'
ms      = require('express/node_modules/connect').session.MemoryStore
pam     = require 'authenticate-pam'
http    = require 'http'

app = express()
server = http.createServer app

checkAuth = (req, res, next) ->
  if req.session.username?
    next()
  else
    res.render 'login'

run = (cmd, arg1, arg2) ->
  throw new Error 'The last argument needs to be a fn.' \
      if arg2? and typeof arg2 isnt 'function' or \
      !arg2? and typeof arg1 isnt 'function'

  options =
    'quiet': true

  if typeof arg1 is 'object'
    options[k] = v for k, v of arg1

  terminal = require('child_process').spawn('bash')

  stdout = ''
  terminal.stdout.on 'data', (data) ->
    stdout += data.toString()
    process.stdout.write data.toString() unless options['quiet']

  stderr = ''
  terminal.stderr.on 'data', (data) ->
    stderr += data.toString()
    process.stderr.write data.toString() unless options['quiet']

  terminal.on 'close', (code) ->
    stdout = stdout.replace(/^\s+|\s+$/g, '')
    stdout = if stdout.length > 0 then stdout.split '\n' else []
    stderr = stderr.replace(/^\s+|\s+$/g, '')
    stderr = if stderr.length > 0 then stderr.split '\n' else []

    callback = if typeof arg1 is 'function' then arg1 else arg2
    if code == 0
      callback null, stdout, stderr
    else
      callback new Error("#{cmd} exited with code #{code}."), stdout, stderr

  console.log "+ #{cmd} (#{new Date()})" unless options['quiet']
  terminal.stdin.write cmd
  terminal.stdin.end()

app.set 'views', __dirname + '/views'
app.set 'view engine', 'ejs'
app.use express.cookieParser()
app.use express.compress()
app.use express.methodOverride()
app.use express.urlencoded()
app.use express.json()
app.use express.session
  secret: 'gitshellw3b4pp'
  key: 'express.sid'
  store: new ms { reapInterval:  60000 * 10 }
app.use express.static(__dirname + '/public')

app.get '/', checkAuth, (req, res) ->
  path = "/home/#{req.session.username}/.ssh/authorized_keys"
  fs.exists path, (existed) ->
    if existed
      fs.readFile path, (err, data) ->
        res.render 'main',
          username: req.session.username
          authorizedKeys: JSON.stringify(data.toString())
    else
      res.render 'main',
        username: req.session.username
        authorizedKeys: JSON.stringify("")

app.get '/logout', checkAuth, (req, res) ->
  req.session.username = undefined
  res.redirect '/'

app.post '/login', (req, res) ->
  pam.authenticate req.body.username, req.body.password, (err) ->
    if err
      console.log err
      res.render 'login'
    else
      req.session.username = req.body.username
      res.redirect '/'

app.post '/updatePassword', checkAuth, (req, res) ->
  run "echo '#{req.session.username}:#{req.body.newPassword}' | chpasswd", (err, stdout, stderr) ->
    res.send(stderr)

app.post '/updateAuthorizedKeys', checkAuth, (req, res) ->
  dir = "/home/#{req.session.username}/.ssh"
  path = "#{dir}/authorized_keys"
  run "mkdir -p #{dir}; chown #{req.session.username} #{dir}", (err, stdout, stderr) ->
    if (err)
      res.send(stderr)
    else
      run "echo \"#{req.body.authorizedKeys}\" > #{path}", (err, stdout, stderr) ->
        if (err)
          res.send(stderr)
        else
          run "chown #{req.session.username} #{path}; chmod 600 #{path}", (err, stdout, stderr) ->
            res.send(stderr)

server.listen 80, ->
  console.log "gitshell webapp starts"
