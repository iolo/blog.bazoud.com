# Requires
path = require 'path'
wintersmith = require 'wintersmith'
express = require 'express'
gzippo = require 'gzippo'
RSS = require 'rss'
fs = require 'fs'
async = require 'async'
util = require 'util'

wintersmithPath = path.dirname require.resolve 'wintersmith'
wintersmithCli = require wintersmithPath + '/cli'

async.waterfall [
  (callback) ->
    # -------------------------------------
    # Wintersmith generation
    wintersmithCli.main (options) ->
      console.log 'Pages generated by Wintersmith.\n'
      callback null, options
  (options, callback) ->
    # -------------------------------------
    # Express configuration
    cache = []
    port = process.env.PORT || 10113
    app = express()
    staticPath = options.output
    app.configure () ->
      console.log 'Express environment: common'
      app.use express.bodyParser()
      app.use express.methodOverride()
      # 404 feed
      app.get '/404.xml', (req, res) ->
        feed = new RSS {
          title: 'Le Blog d Olivier: 404 feed'
          feed_url: 'http://blog.bazoud.com/404.xml'
          site_url: 'http://blog.bazoud.com'
          author: 'Olivier Bazoud'
        }
        for page in cache
          feed.item {
            title:  'blog.bazoud.com: 404 Not Found'
            description: page.referer + ' -> ' + page.path
            url: 'http://blog.bazoud.com/404.xml'
            author: 'Olivier Bazoud'
            date: page.when
          }
        res.header "Content-Type", "text/xml; charset=UTF-8"
        res.send feed.xml(), 200

    app.configure 'development', () ->
      console.log 'Express environment: development'
      app.use express.errorHandler({ dumpExceptions: true, showStack: true })
      app.use gzippo.staticGzip staticPath
    app.configure 'production', () ->
      console.log 'Express environment: production'
      app.use app.errorHandler()
      oneDay = 86400000
      expiresOffset = oneDay * 7
      app.use express.static staticPath, { maxAge: expiresOffset }
    app.listen port
    console.log 'Express server listening on port %d', port
    console.log 'Express server running on http://localhost:%d', port
    console.log 'Express server static: %s', staticPath
    callback null, app, cache, staticPath
  (app, cache, staticPath, callback) ->
    # -------------------------------------
    # Redirects

    # healthCheck
    app.get '/healthCheck', (req, res) ->
      res.send 'ok', 200
    app.get '/healthCheckKO', (req, res) ->
      res.send 'ko', 200
    app.get '/healthCheckRange', (req, res) ->
      res.send '10', 200

    # feeds
    app.get '/feed', (req, res) ->
      res.redirect 301, '/feed.xml'

    app.get '/rss', (req, res) ->
      res.redirect 301, '/rss.xml'

    app.get '/atom', (req, res) ->
      res.redirect 301, '/atom.xml'

    # legacy wordpress
    app.get '/feed/atom', (req, res) ->
      res.redirect 301, '/atom.xml'
    app.get '/feed/rss2', (req, res) ->
      res.redirect 301, '/feed.xml'
    app.get '/feed/rss2/comments', (req, res) ->
      res.redirect 301, 'http://feeds.bazoud.com/bazoud/comments'
    app.get '^/feed/tag/*$', (req, res) ->
      res.redirect 301, '/feed.xml'
    app.get '^/post/tag/*$', (req, res) ->
      res.redirect 301, '/feed.xml'
    app.get '/archive/:year/:mount', (req, res) ->
      res.redirect 301, '/archive/' + req.params.year

    app.get '^/wp-*$', (req, res) ->
      res.send 'Gone', 410

    # quick fix
    app.get '^/post/2008-07-31-can-i-speed-up-the-gwt-compiler.html$', (req, res) ->
      res.redirect 301, '/post/2008-07-31-how-to-speed-up-the-gwt-compiler-part-i.html'
    app.get '^/post/2008-07-31-can-i-speed-up-the-gwt-compiler-part-ii.html$', (req, res) ->
      res.redirect 301, '/post/2008-07-31-how-to-speed-up-the-gwt-compiler-part-ii.html'
    app.get '^/post/2008-07-31-can-i-speed-up-the-gwt-compiler-part-iii.html$', (req, res) ->
      res.redirect 301, '/post/2008-07-31-how-to-speed-up-the-gwt-compiler-part-iii.html'

    # images
    app.get '/public/billets/eclipse1.png', (req, res) ->
      res.redirect 301, '/images/eclipse1.png'
    app.get '/public/billets/feisty/29.png', (req, res) ->
      res.redirect 301, '/images/29.png'
    app.get '/wp-content/uploads/eclipse2.png', (req, res) ->
      res.redirect 301, '/images/eclipse2.png'

    # legacy docpad
    app.get '/post/:id\.html', (req, res) ->
      res.redirect 301, '/articles/' + req.params.id + '/index.html'

    # rewrite wintersmith
    app.get /^\/tag\/([a-zA-Z-0-9\-]+)(?!\html)$/, (req, res) ->
      res.redirect 301, '/tag/' + req.params + '.html'
    app.get /^\/archive\/([0-9]+)(?!\html)$/, (req, res) ->
      res.redirect 301, '/archive/' + req.params + '.html'

    app.get '/articles/:id\.html', (req, res) ->
      res.redirect 301, '/articles/' + req.params.id + '/index.html'

    # 404 Middleware
    app.use (req,res,next) ->
      cache.push { path: req.path, referer : req.header('Referer'), when: new Date() }
      fs.readFile path.join(staticPath, '404.html'), 'utf8', (err, text) ->
        res.send text, 404
  ], (err, result) ->
    console.log 'FAIL: ' + err.message
