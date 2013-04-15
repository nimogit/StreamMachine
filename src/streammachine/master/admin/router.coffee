_u = require("underscore")
express = require "express"
api = require "express-api-helper"
path = require "path"
hamlc = require "haml-coffee"
Assets = require "connect-assets"

module.exports = class Router
    constructor: (opts) ->
        @core = opts?.core
        @port = opts?.port
        
        if !@port
            throw "Admin requires a port"
            
        @core.log.debug "Admin is listening on #{@port}"
        
        @app = express()
        @app.set "views", __dirname + "/views"
        @app.set "view engine", "hamlc"
        @app.engine '.hamlc', hamlc.__express
        
        #@app.use require('connect-assets')()
        
        Assets.jsCompilers.hamlc =
          match: /\.js$/
          compileSync: (sourcePath, source) ->
             assetName = path.basename(sourcePath, '.hamlc')
             compiled = hamlc.template(source, assetName)
             compiled
             
        @app.use Assets()
        
        # -- Param Handlers -- #
        
        @app.param "stream", (req,res,next,key) =>
            # make sure it's a valid stream key
            if key? && s = @core.streams[ key ]
                req.stream = s
                next()
            else
                res.status(404).end "Invalid stream.\n"
                
        # -- options support for CORS -- #
        
        corsFunc = (req,res,next) =>
          res.header('Access-Control-Allow-Origin', '*');
          res.header('Access-Control-Allow-Credentials', true); 
          res.header('Access-Control-Allow-Methods', 'POST, GET, PUT, DELETE, OPTIONS');
          res.header('Access-Control-Allow-Headers', 'Content-Type'); 
          next()
        
        @app.use corsFunc
      
        @app.options "*", (req,res) =>
            res.status(200).end ""
            
        # -- Routing -- #
                
        # list streams
        @app.get "/api/streams", (req,res) =>
            # return JSON version of the status for all streams
            api.ok req, res, @core.streamsInfo()

        # list streams
        @app.get "/api/config", (req,res) =>
            # return JSON version of the status for all streams
            api.ok req, res, @core.config()
            
        # create a stream
        @app.post "/api/streams", express.bodyParser(), (req,res) =>
            # add a new stream
            @core.createStream req.body, (err,stream) =>
                if err
                    api.invalid req, res, err
                else
                    api.ok req, res, stream
        
        # get stream details    
        @app.get "/api/streams/:stream", (req,res) =>
            # get detailed stream information
            api.ok req, res, req.stream.status(true)
        
        # update stream metadata    
        @app.post "/api/streams/:stream/metadata", (req,res) =>
            req.stream.setMetadata req.query, (err,meta) =>
                if err
                    api.invalid req, res, err
                else
                    api.ok req, req, meta
        
        # Promote a source to live    
        @app.post "/api/streams/:stream/promote", (req,res) =>
            # promote a stream source to active
            # We'll just pass on the UUID and leave any logic to the stream
            req.stream.promoteSource req.query.uuid, (err,msg) =>
                if err
                    api.invalid req, res, err
                else
                    api.ok req, res, msg
        
        # Drop a source    
        @app.post "/api/streams/:stream/drop", (req,res) =>
            # drop a stream source
        
        # Delete a stream    
        @app.delete "/api/streams/:stream", (req,res) =>
            # delete a stream
        
        # Get the web UI    
        @app.get /.*/, (req,res) =>
            res.render "layout", 
                core:       @core
                server:     "http://#{req.headers.host}/api"
                streams:    JSON.stringify(@core.streamsInfo())
            
        @server = @app.listen @port      
        