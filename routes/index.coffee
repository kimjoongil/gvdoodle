express = require "express"
dot_runner = require "../lib/dot_runner"
gvid = require "../lib/gvid"
StoreFile = require("../lib/store_file")
StoreGoogle = require("../lib/store_google")
logger = require("../lib/logger")

storeFileFactory = ->
  logger.info("storeFile is ready")
  if process.env.NODE_ENV == 'test'
    new StoreFile("store.test")
  else
    new StoreFile("store")

storeGoogleFactory = ->
  google = (host) ->
    logger.info("storeGoogle is ready for #{host}")
    new StoreGoogle(host)
  if process.env.NODE_ENV == 'test'
    google "store.test.gvdoodle.com"
  else
    google "store.gvdoodle.com"

store = if process.env.GV_STORE == 'local'
  storeFileFactory()
else
  storeGoogleFactory()

router = express.Router()

# GET home page.
router.get "/", (req, res) ->
  res.render "editor"

router.get /^\/[0-9A-Z]{5,6}$/, (req, res) ->
  logger.debug "request for #{req.path}"
  id = req.path.replace(/^\//, '')
  return res.send(404) unless gvid.valid(id)
  res.render "editor", {gvid: id}

router.get /^\/[0-9A-Z]{5,6}\.(gv|meta|svgz?)$/, (req, res) ->
  logger.debug "#{req.path} should have been served by nginx"
  name = req.path.replace(/^\//, '')
  res.type switch
    when /gv$/.test name then 'text/vnd.graphviz'
    when /meta$/.test name then 'application/json'
    when /svgz?$/.test name then 'image/svg+xml'
    else 'application/octet-stream'
  store.readFile name, (err, content) ->
    return res.send(500) if err
    logger.debug content.toString()
    res.send content

router.post "/preview", (req, res) ->
  engine = req.body.engine || 'dot'
  logger.debug "preview request [engine: #{engine}]"
  logger.debug req.body.text
  dot_runner.preview engine, req.body.text, (err, svg) ->
    res.end svg

router.post "/publish", (req, res) ->
  engine = req.body.engine || 'dot'
  meta = {engine: engine, parent: "EMPTY"}
  dot = req.body.text
  store.saveSource meta, dot, (err, id) ->
    dot_runner.preview engine, dot, (err, svg) ->
      console.log "saving... #{id}"
      console.log svg
      store.writeFile "#{id}.svg", svg, (err) ->
        res.send({gvid: id})

router.get "/template/:template", (req, res) ->
  res.render "template/#{req.params.template}"

module.exports = router
